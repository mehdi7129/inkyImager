import Darwin
import Foundation
import XCTest
@testable import ImagerCore

final class FlashWorkspaceTests: XCTestCase {
    private let manager = FileManager.default

    private func withCache(_ test: (URL) throws -> Void) throws {
        let base = URL(fileURLWithPath: try XCTUnwrap(ProcessInfo.processInfo.environment["TMPDIR"]), isDirectory: true)
        let path = base.path.hasPrefix("/var/") ? "/private" + base.path : base.path
        let root = URL(fileURLWithPath: path, isDirectory: true).appendingPathComponent(UUID().uuidString)
        try manager.createDirectory(at: root, withIntermediateDirectories: false, attributes: [.posixPermissions: 0o700])
        defer { try? manager.removeItem(at: root) }
        try test(root.appendingPathComponent("cache"))
    }

    private func addFixtureImage(_ directory: URL) throws -> URL {
        let image = directory.appendingPathComponent("InkyOS.img")
        XCTAssertTrue(manager.createFile(atPath: image.path, contents: Data(repeating: 42, count: 65_536),
                                         attributes: [.posixPermissions: 0o600]))
        return image
    }

    func testCrashReleasesLeaseAndReaperReclaimsExactImage() throws {
        try withCache { cache in
            var workspace: FlashWorkspace? = try FlashWorkspace.create(in: cache)
            let directory = try XCTUnwrap(workspace?.url)
            let image = try addFixtureImage(directory)
            let marker = directory.appendingPathComponent(FlashWorkspace.marker)
            let child = Process()
            child.executableURL = URL(fileURLWithPath: "/usr/bin/perl")
            child.arguments = ["-e", """
                use Fcntl qw(:flock);
                open my $lease, '<', $ARGV[0] or die;
                flock($lease, LOCK_SH) or die;
                $| = 1;
                print "1";
                sleep 120;
                """, marker.path]
            let ready = Pipe()
            child.standardOutput = ready
            try child.run()
            defer {
                if child.isRunning { kill(child.processIdentifier, SIGKILL); child.waitUntilExit() }
            }
            XCTAssertEqual(try ready.fileHandleForReading.read(upToCount: 1), Data("1".utf8))
            workspace = nil
            XCTAssertEqual(FlashWorkspace.reclaimAbandoned(in: cache) { _ in XCTFail("Active lease detached") }, 0)
            XCTAssertTrue(manager.fileExists(atPath: image.path))
            XCTAssertEqual(kill(child.processIdentifier, SIGKILL), 0)
            child.waitUntilExit()
            XCTAssertEqual(child.terminationReason, .uncaughtSignal)
            var detached: [URL] = []
            XCTAssertEqual(FlashWorkspace.reclaimAbandoned(in: cache) { detached.append($0) }, 1)
            XCTAssertEqual(detached, [image])
            XCTAssertFalse(manager.fileExists(atPath: directory.path))
        }
    }

    func testUnmarkedInvalidLinkedAndOverexposedWorkspacesArePreserved() throws {
        try withCache { cache in
            var fixture: FlashWorkspace? = try FlashWorkspace.create(in: cache)
            let directory = try XCTUnwrap(fixture?.url)
            fixture = nil
            let foreign = cache.appendingPathComponent(UUID().uuidString)
            try manager.createDirectory(at: foreign, withIntermediateDirectories: false, attributes: [.posixPermissions: 0o700])
            let foreignFile = try addFixtureImage(foreign)
            let marker = directory.appendingPathComponent(FlashWorkspace.marker)
            let contents = try Data(contentsOf: marker)

            try Data("invalid".utf8).write(to: marker)
            XCTAssertEqual(FlashWorkspace.reclaimAbandoned(in: cache) { _ in XCTFail("Invalid marker") }, 0)
            try contents.write(to: marker)
            try manager.setAttributes([.posixPermissions: 0o755], ofItemAtPath: directory.path)
            XCTAssertEqual(FlashWorkspace.reclaimAbandoned(in: cache) { _ in XCTFail("Public directory") }, 0)
            try manager.setAttributes([.posixPermissions: 0o700], ofItemAtPath: directory.path)
            let image = directory.appendingPathComponent("InkyOS.img")
            try manager.createSymbolicLink(at: image, withDestinationURL: foreignFile)
            XCTAssertEqual(FlashWorkspace.reclaimAbandoned(in: cache) { _ in XCTFail("Symlink detached") }, 0)
            try manager.removeItem(at: image)
            try manager.linkItem(at: foreignFile, to: image)
            XCTAssertEqual(FlashWorkspace.reclaimAbandoned(in: cache) { _ in XCTFail("Hardlink detached") }, 0)
            XCTAssertTrue(manager.fileExists(atPath: foreignFile.path))
            XCTAssertTrue(manager.fileExists(atPath: marker.path))
        }
    }

    func testAbandonedAttachedFATImageIsDetachedBeforeRemoval() throws {
        guard let fixture = ProcessInfo.processInfo.environment["INKY_IMAGER_FAT_FIXTURE"] else {
            throw XCTSkip("Run with an explicit synthetic FAT fixture.")
        }
        let (fd, _) = try regularInput(fixture)
        close(fd)
        try withCache { cache in
            var workspace: FlashWorkspace? = try FlashWorkspace.create(in: cache)
            let directory = try XCTUnwrap(workspace?.url)
            let image = directory.appendingPathComponent("InkyOS.img")
            _ = try ImagePreparation.execute("/bin/cp", ["-c", fixture, image.path])
            try manager.setAttributes([.posixPermissions: 0o600], ofItemAtPath: image.path)
            try ImagePreparation.personalize(image: image,
                wifi: WiFiConfiguration(ssid: "synthetic-test", password: "fixture-only-pass", country: "FR"),
                filename: "inky-imager.json", personalizationSchemaVersion: 2, language: .ja)
            _ = try ImagePreparation.execute("/usr/bin/hdiutil", ["attach", "-nomount", "-readonly", "-plist",
                "-imagekey", "diskimage-class=CRawDiskImage", image.path])
            defer { try? ImagePreparation.detachPrivateImage(image) }

            func appearsAttached() throws -> Bool {
                let raw = try ImagePreparation.execute("/usr/bin/hdiutil", ["info", "-plist"])
                let info = try XCTUnwrap(try PropertyListSerialization.propertyList(from: raw, format: nil) as? [String: Any])
                let entries = try XCTUnwrap(info["images"] as? [[String: Any]])
                return entries.contains { $0["image-path"] as? String == image.path }
            }

            XCTAssertTrue(try appearsAttached())
            workspace = nil
            XCTAssertEqual(FlashWorkspace.reclaimAbandoned(in: cache), 1)
            XCTAssertFalse(try appearsAttached())
            XCTAssertFalse(manager.fileExists(atPath: directory.path))
        }
    }

    func testFailedDetachLeavesImageForLaterCleanup() throws {
        try withCache { cache in
            var workspace: FlashWorkspace? = try FlashWorkspace.create(in: cache)
            let directory = try XCTUnwrap(workspace?.url)
            let image = try addFixtureImage(directory)
            workspace = nil
            XCTAssertEqual(FlashWorkspace.reclaimAbandoned(in: cache) { url in
                XCTAssertEqual(url, image)
                throw ImagerError("fixture_detach_failed")
            }, 0)
            XCTAssertTrue(manager.fileExists(atPath: image.path))
            XCTAssertEqual(FlashWorkspace.reclaimAbandoned(in: cache) { XCTAssertEqual($0, image) }, 1)
        }
    }
}

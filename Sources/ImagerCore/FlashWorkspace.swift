import Darwin
import Foundation
import os

public final class FlashWorkspace {
    static let marker = ".inkyimager-lease"
    private static let stamp = Data("inkyImager workspace v1\n".utf8)
    public static var cache: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Caches/fr.mehdiguiard.inkyimager")
    }

    public let url: URL
    private let parent: Int32
    private let directory: Int32
    private let lease: Int32
    private let owner = getuid()

    private init(url: URL, parent: Int32, directory: Int32, lease: Int32) {
        self.url = url
        self.parent = parent
        self.directory = directory
        self.lease = lease
    }

    deinit {
        close(lease)
        close(directory)
        close(parent)
    }

    public static func create(in cache: URL = cache) throws -> FlashWorkspace {
        let (base, _) = try checkedDirectory(cache.deletingLastPathComponent().path, owner: getuid(), privateLeaf: false)
        defer { close(base) }
        guard mkdirat(base, cache.lastPathComponent, 0o700) == 0 || errno == EEXIST else { throw invalid }
        let (parent, _) = try checkedDirectory(cache.path, owner: getuid(), privateLeaf: true)
        let name = UUID().uuidString
        guard mkdirat(parent, name, 0o700) == 0 else { close(parent); throw invalid }
        let directory = openat(parent, name, O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC)
        let lease = directory < 0 ? -1 : openat(directory, marker,
                                                O_RDWR | O_CREAT | O_EXCL | O_NOFOLLOW | O_CLOEXEC, 0o600)
        do {
            guard lease >= 0, flock(lease, LOCK_SH | LOCK_NB) == 0 else { throw invalid }
            try stamp.withUnsafeBytes { try writeAll(lease, $0) }
            guard fsync(lease) == 0, fsync(directory) == 0, fsync(parent) == 0 else { throw invalid }
            return FlashWorkspace(url: cache.appendingPathComponent(name), parent: parent, directory: directory, lease: lease)
        } catch {
            if lease >= 0 { unlinkat(directory, marker, 0); close(lease) }
            if directory >= 0 { close(directory) }
            unlinkat(parent, name, AT_REMOVEDIR)
            close(parent)
            throw error
        }
    }

    static func acquireLease(in directory: Int32, exclusive: Bool) throws -> Int32? {
        let fd = openat(directory, marker, O_RDONLY | O_NOFOLLOW | O_NONBLOCK | O_CLOEXEC)
        guard fd >= 0 else { throw invalid }
        do {
            let state = try fileInfo(fd)
            guard isPrivateFile(state, owner: getuid()), state.st_size == stamp.count else { throw invalid }
            if flock(fd, (exclusive ? LOCK_EX : LOCK_SH) | LOCK_NB) != 0 {
                if errno == EWOULDBLOCK { close(fd); return nil }
                throw invalid
            }
            var bytes = Data(count: stamp.count)
            let size = bytes.withUnsafeMutableBytes { read(fd, $0.baseAddress, $0.count) }
            guard size == stamp.count, bytes == stamp, sameEntry(directory, marker, state) else { throw invalid }
            return fd
        } catch { close(fd); throw error }
    }

    public static func reclaimAbandoned(in cache: URL = cache,
                                        detach: (URL) throws -> Void = ImagePreparation.detachPrivateImage) -> Int {
        guard let (parent, _) = try? checkedDirectory(cache.path, owner: getuid(), privateLeaf: true) else { return 0 }
        defer { close(parent) }
        var removed = 0
        for name in (try? names(in: parent)) ?? [] where UUID(uuidString: name) != nil {
            let directory = openat(parent, name, O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC)
            guard directory >= 0 else { continue }
            defer { close(directory) }
            var markerState = stat()
            guard fstatat(directory, marker, &markerState, AT_SYMLINK_NOFOLLOW) == 0 else { continue }
            do {
                let info = try fileInfo(directory)
                guard info.st_uid == getuid(), info.st_mode & 0o777 == 0o700 else { throw invalid }
                guard let lease = try acquireLease(in: directory, exclusive: true) else { continue }
                let workspace = FlashWorkspace(url: cache.appendingPathComponent(name),
                                               parent: dup(parent), directory: dup(directory), lease: lease)
                try workspace.removeLocked(detach: detach)
                removed += 1
            } catch {
                Logger(subsystem: "fr.mehdiguiard.inkyimager", category: "cleanup")
                    .warning("Abandoned workspace cleanup skipped after validation or detachment failure")
            }
        }
        return removed
    }

    public func remove() throws {
        // The owning app calls this only after the helper has exited.
        // Keep the shared lease continuously held to exclude other reapers.
        try removeLocked(detach: ImagePreparation.detachPrivateImage)
    }

    private func removeLocked(detach: (URL) throws -> Void) throws {
        let name = url.lastPathComponent
        let info = try fileInfo(directory)
        guard Self.sameEntry(parent, name, info) else { throw Self.invalid }
        let markerInfo = try fileInfo(lease)
        guard Self.sameEntry(directory, Self.marker, markerInfo) else { throw Self.invalid }
        let members = try Self.names(in: directory)
        var files: [(String, stat)] = []
        for member in members where member != Self.marker && member != "boot" {
            let expected = ["InkyOS.img", "request.json", "progress.json"].contains(member)
                || (member.hasPrefix(".progress-") && UUID(uuidString: String(member.dropFirst(10))) != nil)
            var observed = stat()
            guard expected, fstatat(directory, member, &observed, AT_SYMLINK_NOFOLLOW) == 0,
                  Self.isPrivateFile(observed, owner: owner) else { throw Self.invalid }
            files.append((member, observed))
        }
        if let image = files.first(where: { $0.0 == "InkyOS.img" }) {
            guard Self.sameEntry(directory, image.0, image.1) else { throw Self.invalid }
            try detach(url.appendingPathComponent(image.0))
        }
        guard Self.sameEntry(parent, name, info) else { throw Self.invalid }
        if members.contains("boot") {
            let boot = openat(directory, "boot", O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC)
            guard boot >= 0 else { throw Self.invalid }
            defer { close(boot) }
            let state = try fileInfo(boot)
            guard state.st_dev == info.st_dev, state.st_uid == owner, state.st_mode & 0o777 == 0o700,
                  try Self.names(in: boot).isEmpty, Self.sameEntry(directory, "boot", state),
                  unlinkat(directory, "boot", AT_REMOVEDIR) == 0 else { throw Self.invalid }
        }
        for (member, observed) in files {
            guard Self.sameEntry(directory, member, observed), unlinkat(directory, member, 0) == 0 else { throw Self.invalid }
        }
        guard Self.sameEntry(directory, Self.marker, markerInfo), unlinkat(directory, Self.marker, 0) == 0,
              Self.sameEntry(parent, name, info), unlinkat(parent, name, AT_REMOVEDIR) == 0 else { throw Self.invalid }
    }

    private static func names(in dir: Int32) throws -> [String] {
        let fd = openat(dir, ".", O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC)
        guard fd >= 0 else { throw invalid }
        guard let stream = fdopendir(fd) else { close(fd); throw invalid }
        defer { closedir(stream) }
        var result: [String] = []
        while true {
            errno = 0
            guard let entry = readdir(stream) else {
                guard errno == 0 else { throw invalid }
                return result
            }
            let capacity = Int(entry.pointee.d_namlen) + 1
            let name = withUnsafePointer(to: &entry.pointee.d_name) {
                $0.withMemoryRebound(to: CChar.self, capacity: capacity) {
                    String(validatingCString: $0)
                }
            }
            guard let name else { throw invalid }
            if name != "." && name != ".." { result.append(name) }
        }
    }

    private static func sameEntry(_ dir: Int32, _ name: String, _ expected: stat) -> Bool {
        var actual = stat()
        return fstatat(dir, name, &actual, AT_SYMLINK_NOFOLLOW) == 0
            && actual.st_dev == expected.st_dev && actual.st_ino == expected.st_ino
            && actual.st_mode == expected.st_mode
            && (actual.st_mode & S_IFMT == S_IFDIR || actual.st_nlink == expected.st_nlink)
            && actual.st_uid == expected.st_uid
    }

    private static func isPrivateFile(_ state: stat, owner: uid_t) -> Bool {
        state.st_mode & S_IFMT == S_IFREG && state.st_mode & 0o777 == 0o600
            && state.st_uid == owner && state.st_nlink == 1
    }

    private static var invalid: ImagerError { ImagerError("Le dossier de travail n’est pas protégé.") }
}

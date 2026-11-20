import Foundation
import XCTest
@testable import ImagerCore

final class ImagerUpdateCheckerTests: XCTestCase {
    func testNewerVersionUsesNumericComparisonAndExactUniversalInstaller() throws {
        let update = try ImagerUpdateChecker.resolve(data: release(version: "0.10.0"), installedVersion: "0.9.0")
        XCTAssertEqual(update?.version, "0.10.0")
        XCTAssertEqual(update?.downloadURL.absoluteString, installerURL(version: "0.10.0"))
    }

    func testSameAndOlderVersionsDoNotOfferAnInstaller() throws {
        let older = try release(version: "0.1.3", assets: [])
        for installed in ["0.1.3", "0.1.4"] {
            XCTAssertNil(try ImagerUpdateChecker.resolve(data: older, installedVersion: installed), installed)
        }
    }

    func testDraftPrereleaseAndNonNumericVersionAreRejected() throws {
        for data in [try release(draft: true), try release(prerelease: true), try release(version: "0.1.4-rc.1")] {
            XCTAssertThrowsError(try ImagerUpdateChecker.resolve(data: data, installedVersion: "0.1.3")) {
                XCTAssertEqual($0 as? ImagerUpdateChecker.CheckError, .invalidRelease)
            }
        }
    }

    func testNewerReleaseWithUntrustedOrIncompleteAssetsDoesNotOfferAnInstaller() throws {
        let canonical = installerURL(version: "0.1.4")
        for assets in [
            [],
            [asset(url: "https://example.com/inkyImager-0.1.4-Universal.dmg")],
            [asset(url: canonical + "?redirect=1")],
            [asset(url: canonical + "#asset")],
            [asset(url: canonical.replacingOccurrences(of: "/v0.1.4/", with: "/v0.1.5/"))],
            [asset(name: "inkyImager-0.1.4.zip", url: canonical)],
            [asset(url: canonical, state: "new")],
            [asset(url: canonical, size: 0)],
        ] {
            let newer = try release(assets: assets)
            XCTAssertThrowsError(try ImagerUpdateChecker.resolve(data: newer, installedVersion: "0.1.3")) {
                XCTAssertEqual($0 as? ImagerUpdateChecker.CheckError, .missingInstaller)
            }
        }
    }

    func testMissingInstalledVersionAndUnexpectedResponseAreRejected() async throws {
        do {
            _ = try await ImagerUpdateChecker.check(installedVersion: "")
            XCTFail("An unpackaged build must not make an update request")
        } catch {
            XCTAssertEqual(error as? ImagerUpdateChecker.CheckError, .invalidInstalledVersion)
        }
        XCTAssertThrowsError(try ImagerUpdateChecker.resolve(data: Data("{\"message\":\"error\"}".utf8), installedVersion: "0.1.3")) {
            XCTAssertEqual($0 as? ImagerUpdateChecker.CheckError, .invalidRelease)
        }
    }

    private func installerURL(version: String) -> String {
        "https://github.com/mehdi7129/inkyImager/releases/download/v\(version)/inkyImager-\(version)-Universal.dmg"
    }

    private func asset(name: String = "inkyImager-0.1.4-Universal.dmg", url: String,
                       state: String = "uploaded", size: Int = 633_581_199) -> [String: Any] {
        ["name": name, "browser_download_url": url, "state": state, "size": size]
    }

    private func release(version: String = "0.1.4", draft: Bool = false, prerelease: Bool = false,
                         assets: [[String: Any]]? = nil) throws -> Data {
        let defaultAsset = asset(name: "inkyImager-\(version)-Universal.dmg", url: installerURL(version: version))
        return try JSONSerialization.data(withJSONObject: [
            "tag_name": "v\(version)", "draft": draft, "prerelease": prerelease, "assets": assets ?? [defaultAsset],
        ])
    }
}

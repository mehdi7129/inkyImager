import Foundation
import XCTest
@testable import ImagerCore

final class LocalizationTests: XCTestCase {
    private let preferences: [(String, ImagerLanguage)] = [
        ("ar-SA", .ar), ("de-CH", .de), ("en-GB", .en), ("es-MX", .es),
        ("fr-CA", .fr), ("it-CH", .it), ("ja-JP", .ja), ("ko-KR", .ko),
        ("pt-BR", .pt), ("zh-Hans-CN", .zhHans), ("zh-Hant-TW", .zhHant),
    ]

    func testLanguageResolutionUsesPreferenceOrderScriptRegionAndFallback() {
        for (preference, expected) in preferences {
            XCTAssertEqual(ImagerLanguage.resolve(["sv-SE", preference, "fr"]), expected, preference)
        }
        XCTAssertEqual(ImagerLanguage.resolve(["zh-Hant-CN"]), .zhHant)
        XCTAssertEqual(ImagerLanguage.resolve(["zh-Hans-TW"]), .zhHans)
        XCTAssertEqual(ImagerLanguage.resolve(["zh-HK"]), .zhHant)
        XCTAssertEqual(ImagerLanguage.resolve(["zh_MO"]), .zhHant)
        XCTAssertEqual(ImagerLanguage.resolve(["zh-SG"]), .zhHans)
        XCTAssertEqual(ImagerLanguage.resolve(["zh"]), .zhHans)
        XCTAssertEqual(ImagerLanguage.resolve(["pl-PL", "sv-SE"]), .fr)
        XCTAssertEqual(ImagerLanguage.resolve([]), .fr)
    }

    func testShippedBundlesResolveNonSourceStrings() {
        XCTAssertEqual(ImagerLocalization.text("Flasher la carte", language: .en), "Flash SD card")
        XCTAssertEqual(ImagerLocalization.text("Flasher la carte", language: .ja), "SDカードに書き込む")
        XCTAssertEqual(ImagerLocalization.text("Actualiser", language: .zhHans), "刷新")
        XCTAssertEqual(ImagerLocalization.text("Actualiser", language: .zhHant), "重新整理")
        XCTAssertEqual(ImagerLocalization.text("Carte prête", language: .ar), "البطاقة جاهزة")
        XCTAssertEqual(ImagerLocalization.text("Carte prête", language: .fr), "Carte prête")
    }

    func testCapsuleContractForEveryLanguageAndLegacyImage() throws {
        let wifi = WiFiConfiguration(ssid: "Inky localization fixture é", password: "synthetic-password-2026", country: "FR")
        let output = ProcessInfo.processInfo.environment["INKY_IMAGER_CAPSULE_FIXTURE_DIR"].map {
            URL(fileURLWithPath: $0, isDirectory: true)
        }
        if let output { try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true) }

        for (preference, expected) in preferences {
            let language = ImagerLanguage.resolve([preference])
            XCTAssertEqual(language, expected)
            let v2 = try ImagePreparation.configurationData(wifi: wifi, personalizationSchemaVersion: 2, language: language)
            let capsule = try XCTUnwrap(JSONSerialization.jsonObject(with: v2) as? [String: Any])
            XCTAssertEqual(Set(capsule.keys), ["schema_version", "wifi", "language"])
            XCTAssertEqual(capsule["schema_version"] as? Int, 2)
            XCTAssertEqual(capsule["language"] as? String, expected.rawValue)
            XCTAssertEqual(capsule["wifi"] as? [String: String], ["ssid": wifi.ssid, "password": wifi.password, "country": "FR"])
            if let output {
                try v2.write(to: output.appendingPathComponent(expected.rawValue + ".json"), options: .withoutOverwriting)
            }
        }

        let v1 = try ImagePreparation.configurationData(wifi: wifi, personalizationSchemaVersion: 1, language: .ar)
        let legacy = try XCTUnwrap(JSONSerialization.jsonObject(with: v1) as? [String: Any])
        XCTAssertEqual(Set(legacy.keys), ["schema_version", "wifi"])
        XCTAssertEqual(legacy["schema_version"] as? Int, 1)
        if let output { try v1.write(to: output.appendingPathComponent("v1.json"), options: .withoutOverwriting) }
        XCTAssertThrowsError(try ImagePreparation.configurationData(wifi: wifi, personalizationSchemaVersion: 3, language: .en))
    }

    func testManifestDoesNotSilentlyDowngradeUnsupportedCapability() throws {
        let base: [String: Any] = [
            "schemaVersion": 1, "version": "fixture", "imageFile": "InkyOS.img.xz",
            "imageBytes": 1, "configurationFile": "inky-imager.json",
            "compressedSHA256": "fixture", "imageSHA256": "fixture",
        ]
        let decoder = JSONDecoder()
        func version(_ advertisedVersion: Int?) throws -> Int? {
            var manifest = base
            manifest["personalizationSchemaVersion"] = advertisedVersion
            let data = try JSONSerialization.data(withJSONObject: manifest)
            return try decoder.decode(OSManifest.self, from: data).supportedPersonalizationSchemaVersion
        }
        XCTAssertEqual(try version(nil), 1)
        XCTAssertEqual(try version(1), 1)
        XCTAssertEqual(try version(2), 2)
        XCTAssertNil(try version(0))
        XCTAssertNil(try version(3))
    }
}

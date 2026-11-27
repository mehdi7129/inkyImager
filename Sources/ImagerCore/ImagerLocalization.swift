import Foundation

public enum ImagerLanguage: String, CaseIterable, Codable, Sendable {
    case ar, de, en, es, fr, it, ja, ko, pt
    case zhHans = "zh-Hans"
    case zhHant = "zh-Hant"

    public static func resolve(_ preferences: [String]) -> Self {
        for preference in preferences {
            let parts = preference.lowercased().split { $0 == "-" || $0 == "_" }
            guard let base = parts.first else { continue }
            if base == "zh" {
                let qualifiers = parts.dropFirst()
                if qualifiers.contains("hant") { return .zhHant }
                if qualifiers.contains("hans") { return .zhHans }
                if qualifiers.contains(where: { ["tw", "hk", "mo"].contains($0) }) { return .zhHant }
                return .zhHans
            }
            if let match = Self(rawValue: String(base)) { return match }
        }
        return .fr
    }
}

public enum ImagerLocalization {
    static let helperLanguageEnvironment = "INKY_IMAGER_HELPER_LANGUAGE"
    public static let language: ImagerLanguage = {
        if let executable = CommandLine.arguments.first,
           URL(fileURLWithPath: executable).lastPathComponent == "inkyImagerHelper",
           let language = ProcessInfo.processInfo.environment[helperLanguageEnvironment].flatMap(ImagerLanguage.init(rawValue:)) {
            return language
        }
        let preferences = UserDefaults.standard.stringArray(forKey: "AppleLanguages") ?? Locale.preferredLanguages
        return ImagerLanguage.resolve(preferences)
    }()

    public static let locale = Locale(identifier: language.rawValue)
    // SwiftPM resolves its resource bundle for tests and swift run. The
    // packaged executable and helper both find it in Contents/Resources.
    private static let resourceBundle: Bundle = {
        let name = "inkyImager_ImagerCore.bundle"
        if let packaged = Bundle.main.resourceURL?.appendingPathComponent(name),
           let bundle = Bundle(url: packaged) { return bundle }
        if let executable = CommandLine.arguments.first {
            let contents = URL(fileURLWithPath: executable).resolvingSymlinksInPath()
                .deletingLastPathComponent().deletingLastPathComponent()
            if let bundle = Bundle(url: contents.appendingPathComponent("Resources").appendingPathComponent(name)) {
                return bundle
            }
        }
        return .module
    }()

    static func translationBundles(in resources: URL) -> [ImagerLanguage: Bundle] {
        // SwiftPM can lowercase script subtags in generated .lproj directory names.
        guard let directories = try? FileManager.default.contentsOfDirectory(
            at: resources, includingPropertiesForKeys: nil
        ) else { return [:] }
        var translations: [ImagerLanguage: Bundle] = [:]
        for language in ImagerLanguage.allCases {
            let expected = language.rawValue.lowercased() + ".lproj"
            if let directory = directories.first(where: { $0.lastPathComponent.lowercased() == expected }),
               let bundle = Bundle(url: directory) {
                translations[language] = bundle
            }
        }
        return translations
    }

    private static let translations = resourceBundle.resourceURL.map(translationBundles) ?? [:]

    public static func text(_ french: String, language: ImagerLanguage = ImagerLocalization.language) -> String {
        translations[language]?.localizedString(forKey: french, value: french, table: nil) ?? french
    }

    public static func format(_ french: String, _ arguments: CVarArg...) -> String {
        String(format: text(french), locale: locale, arguments: arguments)
    }
}

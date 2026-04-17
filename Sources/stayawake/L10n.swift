import Foundation
import SwiftUI

enum L10n {
    static func s(_ key: String) -> String {
        s(key, language: ConfigStore.shared.config.language)
    }

    static func s(_ key: String, language: AppLanguage) -> String {
        NSLocalizedString(key, bundle: activeBundle(language: language), comment: "")
    }

    static func fmt(_ key: String, _ args: CVarArg...) -> String {
        fmt(key, language: ConfigStore.shared.config.language, args: args)
    }

    static func fmt(_ key: String, language: AppLanguage, _ args: CVarArg...) -> String {
        fmt(key, language: language, args: args)
    }

    private static func fmt(_ key: String, language: AppLanguage, args: [CVarArg]) -> String {
        let pattern = NSLocalizedString(key, bundle: activeBundle(language: language), comment: "")
        return String(format: pattern, arguments: args)
    }

    static func text(_ key: String) -> Text {
        Text(s(key))
    }

    static func text(_ key: String, language: AppLanguage) -> Text {
        Text(s(key, language: language))
    }

    private static func activeBundle(language: AppLanguage) -> Bundle {
        guard let lproj = language.lprojName else {
            return AppResources.bundle
        }
        let root = AppResources.bundle.bundleURL
        // SwiftPM's resource processor lowercases `.lproj` directory names, but a
        // hand-copied bundle may keep the original case. Try both so lookups work
        // in either layout.
        for name in [lproj, lproj.lowercased()] {
            let url = root.appendingPathComponent("\(name).lproj", isDirectory: true)
            if FileManager.default.fileExists(atPath: url.path),
               let bundle = Bundle(url: url) {
                return bundle
            }
        }
        return AppResources.bundle
    }
}

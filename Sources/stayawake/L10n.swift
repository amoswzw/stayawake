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
        guard let lproj = language.lprojName,
              let path = AppResources.bundle.path(forResource: lproj, ofType: "lproj"),
              let bundle = Bundle(path: path)
        else {
            return AppResources.bundle
        }
        return bundle
    }
}

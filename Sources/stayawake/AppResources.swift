import Foundation

enum AppResources {
    private static let resourceBundleName = "stayawake_stayawake.bundle"

    static let bundle: Bundle = {
        let executableURL = URL(fileURLWithPath: CommandLine.arguments.first ?? "")
            .deletingLastPathComponent()

        let candidates = [
            Bundle.main.resourceURL?.appendingPathComponent(resourceBundleName, isDirectory: true),
            Bundle.main.bundleURL
                .appendingPathComponent("Contents", isDirectory: true)
                .appendingPathComponent("Resources", isDirectory: true)
                .appendingPathComponent(resourceBundleName, isDirectory: true),
            Bundle.main.bundleURL.appendingPathComponent(resourceBundleName, isDirectory: true),
            executableURL.appendingPathComponent(resourceBundleName, isDirectory: true)
        ]

        for url in candidates {
            guard let url, let bundle = Bundle(url: url) else { continue }
            return bundle
        }

        return .module
    }()
}

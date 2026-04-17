import AppKit

enum FrontmostAppProbe {
    struct Info: Equatable {
        let bundleID: String?
        let name: String?
    }

    static func current() -> Info {
        let app = NSWorkspace.shared.frontmostApplication
        return Info(bundleID: app?.bundleIdentifier, name: app?.localizedName)
    }
}

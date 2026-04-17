import AppKit

enum FullscreenProbe {
    struct Info: Equatable {
        let active: Bool
        let ownerBundleID: String?
    }

    static func current() -> Info? {
        guard let list = CGWindowListCopyWindowInfo(
            [.optionOnScreenOnly, .excludeDesktopElements],
            kCGNullWindowID
        ) as? [[String: Any]] else { return nil }

        let screenBounds: [CGRect] = NSScreen.screens.map { $0.frame }
        if screenBounds.isEmpty { return Info(active: false, ownerBundleID: nil) }

        for entry in list {
            guard let boundsDict = entry[kCGWindowBounds as String] as? [String: CGFloat],
                  let layer = entry[kCGWindowLayer as String] as? Int,
                  layer == 0
            else { continue }

            let x = boundsDict["X"] ?? 0
            let y = boundsDict["Y"] ?? 0
            let w = boundsDict["Width"] ?? 0
            let h = boundsDict["Height"] ?? 0
            let rect = CGRect(x: x, y: y, width: w, height: h)

            for screen in screenBounds where rectCoversScreen(rect, screen: screen) {
                return Info(active: true, ownerBundleID: ownerBundleID(from: entry))
            }
        }
        return Info(active: false, ownerBundleID: nil)
    }

    private static func rectCoversScreen(_ rect: CGRect, screen: CGRect) -> Bool {
        let tol: CGFloat = 2
        return abs(rect.width - screen.width) < tol &&
               abs(rect.height - screen.height) < tol
    }

    private static func ownerBundleID(from entry: [String: Any]) -> String? {
        guard let pidNumber = entry[kCGWindowOwnerPID as String] as? NSNumber else { return nil }
        let app = NSRunningApplication(processIdentifier: pid_t(pidNumber.intValue))
        return app?.bundleIdentifier
    }
}

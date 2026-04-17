import AppKit
import Combine
import SwiftUI

@MainActor
final class MenuBarController: NSObject {
    private let statusItem: NSStatusItem
    private let coordinator: AppCoordinator
    private var cancellables = Set<AnyCancellable>()
    private var settingsWindow: NSWindow?
    private var logsWindow: NSWindow?

    private static let menuTimeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss"
        return f
    }()

    init(coordinator: AppCoordinator) {
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        self.coordinator = coordinator
        super.init()
        configureButton()
        rebuildMenu()
        coordinator.$isAwake
            .combineLatest(coordinator.$lastAction, coordinator.$manualOverride)
            .combineLatest(coordinator.$assertionReason)
            .receive(on: RunLoop.main)
            .sink { [weak self] _, _ in
                self?.refresh()
            }
            .store(in: &cancellables)
        coordinator.$keepAwakeTiming
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.refresh()
            }
            .store(in: &cancellables)
        NotificationCenter.default.publisher(for: ConfigStore.didChangeNotification)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.refresh()
            }
            .store(in: &cancellables)
    }

    private func configureButton() {
        guard let button = statusItem.button else { return }
        button.image = Self.iconImage(awake: false)
        button.imagePosition = .imageOnly
        button.toolTip = "stayawake"
    }

    private static func iconImage(awake: Bool) -> NSImage {
        if let image = statusTemplateImage(named: awake ? "status-awake-template" : "status-sleep-template") {
            return image
        }

        let size = NSSize(width: 22, height: 22)
        let img = NSImage(size: size, flipped: false) { rect in
            let center = NSPoint(x: rect.midX, y: rect.midY)
            let strokeWidth: CGFloat = 2.0

            NSColor.black.setStroke()
            NSColor.black.setFill()

            if awake {
                let clampTop = NSBezierPath(roundedRect: NSRect(
                    x: center.x - 5.6,
                    y: rect.maxY - 6.5,
                    width: 11.2,
                    height: 3.8
                ), xRadius: 1.8, yRadius: 1.8)
                clampTop.fill()

                let clampLeft = NSBezierPath()
                clampLeft.move(to: NSPoint(x: center.x - 4.0, y: rect.maxY - 5.2))
                clampLeft.line(to: NSPoint(x: center.x - 7.0, y: center.y + 0.9))
                clampLeft.line(to: NSPoint(x: center.x - 3.1, y: center.y + 0.9))
                clampLeft.lineWidth = strokeWidth
                clampLeft.lineJoinStyle = .round
                clampLeft.lineCapStyle = .round
                clampLeft.stroke()

                let clampRight = NSBezierPath()
                clampRight.move(to: NSPoint(x: center.x + 4.0, y: rect.maxY - 5.2))
                clampRight.line(to: NSPoint(x: center.x + 7.0, y: center.y + 0.9))
                clampRight.line(to: NSPoint(x: center.x + 3.1, y: center.y + 0.9))
                clampRight.lineWidth = strokeWidth
                clampRight.lineJoinStyle = .round
                clampRight.lineCapStyle = .round
                clampRight.stroke()

                let pinnedBody = NSBezierPath()
                pinnedBody.move(to: NSPoint(x: rect.minX + 4.0, y: center.y - 1.8))
                pinnedBody.curve(
                    to: NSPoint(x: rect.maxX - 4.0, y: center.y - 1.8),
                    controlPoint1: NSPoint(x: rect.minX + 7.5, y: rect.minY + 2.6),
                    controlPoint2: NSPoint(x: rect.maxX - 7.5, y: rect.minY + 2.6)
                )
                pinnedBody.lineWidth = strokeWidth
                pinnedBody.lineCapStyle = .round
                pinnedBody.stroke()

                let pinch = NSBezierPath()
                pinch.move(to: NSPoint(x: center.x - 2.6, y: center.y + 0.5))
                pinch.line(to: NSPoint(x: center.x + 2.6, y: center.y + 0.5))
                pinch.lineWidth = 1.5
                pinch.lineCapStyle = .round
                pinch.stroke()
            } else {
                let fallenBody = NSBezierPath()
                fallenBody.move(to: NSPoint(x: rect.minX + 3.0, y: center.y + 2.0))
                fallenBody.curve(
                    to: NSPoint(x: rect.maxX - 3.0, y: center.y + 2.0),
                    controlPoint1: NSPoint(x: rect.minX + 7.0, y: rect.minY + 1.2),
                    controlPoint2: NSPoint(x: rect.maxX - 7.0, y: rect.minY + 1.2)
                )
                fallenBody.lineWidth = strokeWidth
                fallenBody.lineCapStyle = .round
                fallenBody.stroke()

                let shadow = NSBezierPath()
                shadow.move(to: NSPoint(x: rect.minX + 6.0, y: rect.minY + 4.0))
                shadow.line(to: NSPoint(x: rect.maxX - 6.0, y: rect.minY + 4.0))
                shadow.lineWidth = 1.5
                shadow.lineCapStyle = .round
                shadow.stroke()
            }
            return true
        }
        img.isTemplate = true
        return img
    }

    private static func statusTemplateImage(named name: String) -> NSImage? {
        guard
            let url = AppResources.bundle.url(forResource: name, withExtension: "png"),
            let image = NSImage(contentsOf: url)
        else {
            return nil
        }

        image.size = NSSize(width: 22, height: 22)
        image.isTemplate = true
        return image
    }

    private func refresh() {
        statusItem.button?.image = Self.iconImage(awake: coordinator.isAwake)
        rebuildMenu()
    }

    private func rebuildMenu() {
        let menu = NSMenu()

        let statusText: String
        if coordinator.manualOverride != nil {
            statusText = L10n.s("status.manual_awake")
        } else {
            statusText = coordinator.isAwake ? L10n.s("status.awake") : L10n.s("status.sleepable")
        }
        let statusItem = NSMenuItem(title: statusText, action: nil, keyEquivalent: "")
        statusItem.isEnabled = false
        statusItem.attributedTitle = NSAttributedString(
            string: statusText,
            attributes: [
                .font: NSFont.systemFont(ofSize: 13, weight: .semibold),
                .foregroundColor: statusColor()
            ]
        )
        statusItem.image = Self.iconImage(awake: coordinator.isAwake)
        menu.addItem(statusItem)

        let reasonText = coordinator.assertionReason ?? coordinator.lastAction.reasonText
        if !reasonText.isEmpty {
            let reasonItem = NSMenuItem(
                title: L10n.fmt("status.reason_format", reasonText),
                action: nil,
                keyEquivalent: ""
            )
            reasonItem.isEnabled = false
            menu.addItem(reasonItem)
        }

        if let timing = coordinator.keepAwakeTiming {
            let timingItem = NSMenuItem(
                title: L10n.fmt("status.next_check_format", timing),
                action: nil,
                keyEquivalent: ""
            )
            timingItem.isEnabled = false
            menu.addItem(timingItem)
        }

        let modeText: String
        if let override = coordinator.manualOverride {
            switch override {
            case .untilOff:
                modeText = L10n.s("mode.manual_until_off")
            case .timed(let until):
                modeText = L10n.fmt("mode.manual_until_format", Self.fmtTime(until))
            }
        } else {
            modeText = L10n.s("mode.auto")
        }
        let modeItem = NSMenuItem(title: modeText, action: nil, keyEquivalent: "")
        modeItem.isEnabled = false
        menu.addItem(modeItem)

        let summaryItem = NSMenuItem(
            title: coordinator.isAwake ? L10n.s("status.summary_awake") : L10n.s("status.summary_sleepable"),
            action: nil,
            keyEquivalent: ""
        )
        summaryItem.isEnabled = false
        menu.addItem(summaryItem)

        menu.addItem(.separator())
        addRecentLogs(to: menu)

        menu.addItem(.separator())

        let keep30 = makeItem(L10n.s("menu.keep_30"), #selector(keep30))
        keep30.state = timedOverrideIsNear(minutes: 30) ? .on : .off
        menu.addItem(keep30)

        let keep1h = makeItem(L10n.s("menu.keep_1h"), #selector(keep1h))
        keep1h.state = timedOverrideIsNear(minutes: 60) ? .on : .off
        menu.addItem(keep1h)

        let keepUntilOff = makeItem(L10n.s("menu.keep_until_off"), #selector(keepUntilOff))
        if case .untilOff = coordinator.manualOverride {
            keepUntilOff.state = .on
            keepUntilOff.isEnabled = false
        }
        menu.addItem(keepUntilOff)

        let resume = makeItem(L10n.s("menu.resume_auto"), #selector(resumeAuto))
        resume.isEnabled = coordinator.manualOverride != nil
        menu.addItem(resume)

        menu.addItem(.separator())

        let settings = makeItem(L10n.s("menu.settings"), #selector(openSettings))
        settings.state = settingsWindow?.isVisible == true ? .on : .off
        menu.addItem(settings)

        let logs = makeItem(L10n.s("menu.logs"), #selector(openLogs))
        logs.state = logsWindow?.isVisible == true ? .on : .off
        menu.addItem(logs)

        menu.addItem(.separator())
        menu.addItem(makeItem(L10n.s("menu.quit"), #selector(quit)))

        self.statusItem.menu = menu
    }

    private func addRecentLogs(to menu: NSMenu) {
        let header = NSMenuItem(title: L10n.s("menu.logs_recent"), action: nil, keyEquivalent: "")
        header.isEnabled = false
        header.attributedTitle = NSAttributedString(
            string: L10n.s("menu.logs_recent"),
            attributes: [
                .font: NSFont.systemFont(ofSize: 12, weight: .semibold),
                .foregroundColor: NSColor.secondaryLabelColor
            ]
        )
        menu.addItem(header)

        let events = EventLog.shared.recent(limit: 5)
        if events.isEmpty {
            let empty = NSMenuItem(title: L10n.s("menu.logs_empty"), action: nil, keyEquivalent: "")
            empty.isEnabled = false
            menu.addItem(empty)
            return
        }

        for event in events {
            let item = makeItem(menuLogTitle(for: event), #selector(openLogDetail(_:)))
            item.representedObject = event.id.uuidString
            item.attributedTitle = attributedLogTitle(for: event)
            item.toolTip = event.note.map { "\(event.reason)\n\($0)" } ?? event.reason
            menu.addItem(item)
        }
    }

    private func menuLogTitle(for event: Event) -> String {
        let time = Self.menuTimeFormatter.string(from: event.timestamp)
        let action = actionLabel(for: event.action)
        return "\(time)  \(action)  \(shortReason(event.reason))"
    }

    private func attributedLogTitle(for event: Event) -> NSAttributedString {
        let title = menuLogTitle(for: event)
        let attributed = NSMutableAttributedString(
            string: title,
            attributes: [
                .font: NSFont.systemFont(ofSize: 12),
                .foregroundColor: NSColor.labelColor
            ]
        )

        let action = actionLabel(for: event.action)
        let nsTitle = title as NSString
        let range = nsTitle.range(of: action)
        if range.location != NSNotFound {
            attributed.addAttributes(
                [
                    .font: NSFont.systemFont(ofSize: 12, weight: .semibold),
                    .foregroundColor: actionColor(for: event.action)
                ],
                range: range
            )
        }

        return attributed
    }

    private func shortReason(_ reason: String) -> String {
        let maxLength = 44
        guard reason.count > maxLength else { return reason }
        return String(reason.prefix(maxLength - 3)) + "..."
    }

    private func statusColor() -> NSColor {
        if coordinator.manualOverride != nil || coordinator.isAwake {
            return .systemOrange
        }
        return .systemBlue
    }

    private func actionColor(for action: String) -> NSColor {
        switch action {
        case "KEEP_AWAKE", "MANUAL": return .systemOrange
        case "ALLOW_SLEEP_RELEASED", "ALLOW_SLEEP_SYSTEM": return .systemBlue
        case "START", "AUTO": return .systemGreen
        case "ERROR": return .systemRed
        case "STOP": return .secondaryLabelColor
        default: return .labelColor
        }
    }

    private func actionLabel(for action: String) -> String {
        switch action {
        case "START": return L10n.s("logs.action.start")
        case "STOP": return L10n.s("logs.action.stop")
        case "MANUAL": return L10n.s("logs.action.manual")
        case "AUTO": return L10n.s("logs.action.auto")
        case "KEEP_AWAKE": return L10n.s("logs.action.keep_awake")
        case "ALLOW_SLEEP_RELEASED": return L10n.s("logs.action.allow_sleep_released")
        case "ALLOW_SLEEP_SYSTEM": return L10n.s("logs.action.allow_sleep_system")
        case "ERROR": return L10n.s("logs.action.error")
        default: return action
        }
    }

    private func makeItem(_ title: String, _ action: Selector) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
        item.target = self
        return item
    }

    private func timedOverrideIsNear(minutes: Int) -> Bool {
        guard case .timed(let until) = coordinator.manualOverride else { return false }
        let remainingMinutes = Int(ceil(until.timeIntervalSinceNow / 60))
        return abs(remainingMinutes - minutes) <= 1
    }

    @objc private func keep30() {
        coordinator.setManualOverride(.timed(until: Date().addingTimeInterval(30 * 60)))
    }
    @objc private func keep1h() {
        coordinator.setManualOverride(.timed(until: Date().addingTimeInterval(60 * 60)))
    }
    @objc private func keepUntilOff() {
        coordinator.setManualOverride(.untilOff)
    }
    @objc private func resumeAuto() {
        coordinator.setManualOverride(nil)
    }
    @objc private func openSettings() {
        showWindow(
            title: L10n.s("window.settings"),
            existing: &settingsWindow,
            size: NSSize(width: 680, height: 660)
        ) {
            AnyView(SettingsView(coordinator: coordinator))
        }
    }
    @objc private func openLogs() {
        showLogs(selectedEventID: nil)
    }
    @objc private func openLogDetail(_ sender: NSMenuItem) {
        let selectedEventID = (sender.representedObject as? String).flatMap(UUID.init(uuidString:))
        showLogs(selectedEventID: selectedEventID)
    }

    private func showLogs(selectedEventID: Event.ID?) {
        let hosting = NSHostingController(rootView: AnyView(LogsView(initialSelectedEventID: selectedEventID)))
        if let window = logsWindow {
            window.contentViewController = hosting
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: NSSize(width: 680, height: 660)),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = L10n.s("window.logs")
        window.contentViewController = hosting
        window.isReleasedWhenClosed = false
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        logsWindow = window
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }

    private func showWindow(
        title: String,
        existing: inout NSWindow?,
        size: NSSize,
        content: () -> AnyView
    ) {
        if let w = existing {
            w.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        let hosting = NSHostingController(rootView: content())
        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = title
        window.contentViewController = hosting
        window.isReleasedWhenClosed = false
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        existing = window
    }

    private static func fmtTime(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateStyle = .none
        f.timeStyle = .short
        return f.string(from: date)
    }
}

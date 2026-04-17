import SwiftUI

struct LogsView: View {
    @State private var events: [Event]
    @State private var selectedEventID: Event.ID?
    @State private var localizationVersion: Int = 0

    init(initialSelectedEventID: Event.ID? = nil) {
        _events = State(initialValue: EventLog.shared.recent(limit: 5))
        _selectedEventID = State(initialValue: initialSelectedEventID)
    }

    private let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss"
        return f
    }()

    private let detailTimeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .medium
        return f
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider()

            if events.isEmpty {
                VStack(spacing: 12) {
                    Spacer()
                    Image(systemName: "clock.badge.checkmark")
                        .font(.system(size: 34, weight: .regular))
                        .foregroundStyle(.secondary)
                    L10n.text("logs.empty")
                        .font(.headline)
                    L10n.text("logs.empty_detail")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                content
            }
        }
        .frame(minWidth: 640, minHeight: 620)
        .background(Color(nsColor: .windowBackgroundColor))
        .id(localizationVersion)
        .onAppear {
            selectNewestIfNeeded()
        }
        .onReceive(NotificationCenter.default.publisher(for: ConfigStore.didChangeNotification)) { _ in
            localizationVersion += 1
        }
    }

    private var header: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.accentColor.opacity(0.12))
                Image(systemName: "list.bullet.rectangle.portrait")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(Color.accentColor)
            }
            .frame(width: 42, height: 42)

            VStack(alignment: .leading, spacing: 3) {
                L10n.text("logs.title")
                    .font(.title2.weight(.semibold))
                L10n.text("logs.subtitle")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text(L10n.fmt("logs.recent_count_format", events.count))
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 9)
                .padding(.vertical, 4)
                .background(
                    Capsule()
                        .fill(Color(nsColor: .separatorColor).opacity(0.16))
                )

            Button {
                events = EventLog.shared.recent(limit: 5)
                selectNewestIfNeeded()
            } label: {
                Label(L10n.s("logs.refresh"), systemImage: "arrow.clockwise")
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 18)
    }

    private var content: some View {
        HStack(alignment: .top, spacing: 0) {
            List(events, selection: $selectedEventID) { event in
                logRow(event)
                    .tag(event.id)
            }
            .listStyle(.sidebar)
            .frame(minWidth: 300, idealWidth: 340, maxWidth: 390)

            Divider()

            detailPanel
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }

    private func logRow(_ event: Event) -> some View {
        let actionColor = color(for: event.action)

        return HStack(alignment: .top, spacing: 10) {
            RoundedRectangle(cornerRadius: 2)
                .fill(actionColor)
                .frame(width: 4)

            VStack(alignment: .leading, spacing: 7) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(actionLabel(for: event.action))
                        .font(.system(.caption, design: .monospaced).weight(.semibold))
                        .foregroundStyle(actionColor)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(
                            Capsule()
                                .fill(actionColor.opacity(0.14))
                        )

                    Spacer(minLength: 8)

                    Text(timeFormatter.string(from: event.timestamp))
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(.secondary)
                }

                Text(event.reason)
                    .font(.callout.weight(.medium))
                    .lineLimit(2)

                if let duration = durationText(for: event) {
                    Label(duration, systemImage: "timer")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                } else if let note = event.note, !note.isEmpty {
                    Text(note)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
        }
        .padding(.vertical, 8)
    }

    private var detailPanel: some View {
        let event = selectedEvent
        let actionColor = event.map { color(for: $0.action) } ?? .secondary

        return ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                if let event {
                    HStack(alignment: .center, spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(actionColor.opacity(0.14))
                            Image(systemName: iconName(for: event.action))
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundStyle(actionColor)
                        }
                        .frame(width: 44, height: 44)

                        VStack(alignment: .leading, spacing: 3) {
                            Text(actionLabel(for: event.action))
                                .font(.title3.weight(.semibold))
                            Text(detailTimeFormatter.string(from: event.timestamp))
                                .font(.callout)
                                .foregroundStyle(.secondary)
                        }
                    }

                    detailField(title: L10n.s("logs.column.reason"), value: event.reason)

                    if let note = event.note, !note.isEmpty {
                        detailField(title: L10n.s("logs.detail.note"), value: note)
                    }

                    detailField(
                        title: L10n.s("logs.column.duration"),
                        value: durationText(for: event) ?? L10n.s("logs.detail.none")
                    )
                } else {
                    VStack(spacing: 10) {
                        Image(systemName: "sidebar.left")
                            .font(.system(size: 28, weight: .regular))
                            .foregroundStyle(.secondary)
                        L10n.text("logs.detail.placeholder")
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, minHeight: 360)
                }
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(actionColor.opacity(event == nil ? 0 : 0.035))
    }

    private func detailField(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
            Text(value)
                .font(.body)
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var selectedEvent: Event? {
        if let selectedEventID,
           let event = events.first(where: { $0.id == selectedEventID }) {
            return event
        }
        return events.first
    }

    private func selectNewestIfNeeded() {
        guard !events.isEmpty else {
            selectedEventID = nil
            return
        }
        if let selectedEventID,
           events.contains(where: { $0.id == selectedEventID }) {
            return
        }
        selectedEventID = events.first?.id
    }

    private func color(for action: String) -> Color {
        switch action {
        case "KEEP_AWAKE", "MANUAL": return .orange
        case "ALLOW_SLEEP_RELEASED", "ALLOW_SLEEP_SYSTEM": return .blue
        case "START", "AUTO": return .green
        case "ERROR": return .red
        case "STOP": return .secondary
        default: return .primary
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

    private func iconName(for action: String) -> String {
        switch action {
        case "KEEP_AWAKE", "MANUAL": return "bolt.fill"
        case "ALLOW_SLEEP_RELEASED", "ALLOW_SLEEP_SYSTEM": return "moon.zzz.fill"
        case "START": return "play.fill"
        case "AUTO": return "arrow.triangle.2.circlepath"
        case "ERROR": return "exclamationmark.triangle.fill"
        case "STOP": return "stop.fill"
        default: return "circle.fill"
        }
    }

    private func durationText(for event: Event) -> String? {
        if let until = event.until {
            return L10n.fmt(
                "duration.until_format",
                timeFormatter.string(from: until),
                remainingText(until)
            )
        }
        return event.duration
    }

    private func remainingText(_ date: Date) -> String {
        let seconds = max(0, Int(ceil(date.timeIntervalSinceNow)))
        if seconds == 0 {
            return L10n.s("duration.expired")
        }
        if seconds >= 3600 {
            return L10n.fmt("duration.remaining_hours_format", seconds / 3600, (seconds % 3600) / 60)
        }
        return L10n.fmt("duration.remaining_minutes_format", max(1, Int(ceil(Double(seconds) / 60))))
    }
}

import AppKit
import SwiftUI

struct SettingsView: View {
    @ObservedObject private var coordinator: AppCoordinator
    @State private var cfg: Config = ConfigStore.shared.config
    @State private var newProcess: String = ""
    @State private var newWorkBundle: String = ""
    @State private var newBlackBundle: String = ""
    @State private var launchAtLoginError: String?

    init(coordinator: AppCoordinator) {
        self.coordinator = coordinator
    }

    var body: some View {
        VStack(spacing: 0) {
            settingsHeader
            Divider()
            TabView {
                generalTab
                    .padding(.top, 8)
                    .tabItem { Label(s("settings.tab.general"), systemImage: "gearshape") }
                rulesTab
                    .padding(.top, 8)
                    .tabItem { Label(s("settings.tab.rules"), systemImage: "list.bullet.rectangle") }
                advancedTab
                    .padding(.top, 8)
                    .tabItem { Label(s("settings.tab.advanced"), systemImage: "slider.horizontal.3") }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
        .frame(minWidth: 640, minHeight: 620)
        .background(Color(nsColor: .windowBackgroundColor))
        .onChange(of: cfg) { newValue in
            ConfigStore.shared.update { $0 = newValue }
        }
        .onAppear {
            let enabled = LaunchAtLoginManager.isEnabled
            if cfg.launchAtLogin != enabled {
                cfg.launchAtLogin = enabled
            }
        }
    }

    private var settingsHeader: some View {
        HStack(spacing: 14) {
            settingsIcon
            .frame(width: 44, height: 44)

            VStack(alignment: .leading, spacing: 3) {
                text("settings.title")
                    .font(.title2.weight(.semibold))
                text("settings.subtitle")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 18)
    }

    private var settingsIcon: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.accentColor.opacity(0.12))

            if let image = statusTemplateImage(named: coordinator.isAwake ? "status-awake-template" : "status-sleep-template") {
                Image(nsImage: image)
                    .resizable()
                    .renderingMode(.template)
                    .aspectRatio(contentMode: .fit)
                    .foregroundStyle(Color.accentColor)
                    .padding(8)
            } else {
                Image(systemName: "bolt.fill")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(Color.accentColor)
            }
        }
    }

    private func statusTemplateImage(named name: String) -> NSImage? {
        guard
            let url = Bundle.module.url(forResource: name, withExtension: "png"),
            let image = NSImage(contentsOf: url)
        else {
            return nil
        }

        image.isTemplate = true
        return image
    }

    private func s(_ key: String) -> String {
        L10n.s(key, language: cfg.language)
    }

    private func f(_ key: String, _ args: CVarArg...) -> String {
        String(format: L10n.s(key, language: cfg.language), arguments: args)
    }

    private func text(_ key: String) -> Text {
        L10n.text(key, language: cfg.language)
    }

    private var generalTab: some View {
        Form {
            Section(s("settings.section.launch")) {
                Toggle(isOn: Binding(
                    get: { cfg.launchAtLogin },
                    set: setLaunchAtLogin
                )) {
                    text("settings.launch_at_login")
                }
                if let launchAtLoginError {
                    Text(launchAtLoginError)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }
            }
            Section(s("settings.section.language")) {
                Picker(selection: Binding(
                    get: { cfg.language },
                    set: { cfg.language = $0 }
                )) {
                    ForEach(AppLanguage.allCases) { language in
                        Text(L10n.s(language.titleKey, language: cfg.language)).tag(language)
                    }
                } label: {
                    text("settings.language")
                }
                .pickerStyle(.menu)
            }
            Section(s("settings.section.idle")) {
                HStack {
                    text("settings.idle_threshold_min")
                    Spacer()
                    TextField("", value: Binding(
                        get: { Int(cfg.idleThresholdSeconds / 60) },
                        set: { cfg.idleThresholdSeconds = TimeInterval(max(1, $0) * 60) }
                    ), format: .number)
                    .frame(width: 80)
                    .multilineTextAlignment(.trailing)
                }
            }
            Section(s("settings.section.sampling")) {
                HStack {
                    text("settings.sample_interval_sec")
                    Spacer()
                    TextField("", value: Binding(
                        get: { Int(cfg.sampleIntervalSeconds) },
                        set: { cfg.sampleIntervalSeconds = TimeInterval(max(5, min($0, 120))) }
                    ), format: .number)
                    .frame(width: 80)
                    .multilineTextAlignment(.trailing)
                }
                HStack {
                    text("settings.cooldown_sec")
                    Spacer()
                    TextField("", value: Binding(
                        get: { Int(cfg.cooldownSeconds) },
                        set: { cfg.cooldownSeconds = TimeInterval(max(0, $0)) }
                    ), format: .number)
                    .frame(width: 80)
                    .multilineTextAlignment(.trailing)
                }
            }
        }
        .formStyle(.grouped)
    }

    private var rulesTab: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                listSection(
                    titleKey: "settings.rules.task_processes.title",
                    items: Binding(
                        get: { Array(cfg.taskProcessNames).sorted() },
                        set: { cfg.taskProcessNames = Set($0) }
                    ),
                    newItem: $newProcess,
                    placeholderKey: "settings.rules.task_processes.placeholder"
                )

                listSection(
                    titleKey: "settings.rules.work_apps.title",
                    items: Binding(
                        get: { Array(cfg.workBundleIDs).sorted() },
                        set: { cfg.workBundleIDs = Set($0) }
                    ),
                    newItem: $newWorkBundle,
                    placeholderKey: "settings.rules.work_apps.placeholder"
                )

                listSection(
                    titleKey: "settings.rules.blacklist.title",
                    items: Binding(
                        get: { Array(cfg.blacklistBundleIDs).sorted() },
                        set: { cfg.blacklistBundleIDs = Set($0) }
                    ),
                    newItem: $newBlackBundle,
                    placeholderKey: "settings.rules.blacklist.placeholder"
                )
            }
            .padding(.vertical, 12)
        }
    }

    private var advancedTab: some View {
        Form {
            Section(s("settings.section.thresholds")) {
                HStack {
                    text("settings.cpu_threshold")
                    Spacer()
                    TextField("", value: Binding(
                        get: { Int(cfg.cpuThreshold * 100) },
                        set: { cfg.cpuThreshold = Double(max(1, min($0, 100))) / 100 }
                    ), format: .number)
                    .frame(width: 80)
                    .multilineTextAlignment(.trailing)
                    Text("%")
                }
                HStack {
                    text("settings.network_threshold")
                    Spacer()
                    TextField("", value: Binding(
                        get: { Int(cfg.networkThresholdBytesPerSec / 1024) },
                        set: { cfg.networkThresholdBytesPerSec = Double(max(1, $0)) * 1024 }
                    ), format: .number)
                    .frame(width: 80)
                    .multilineTextAlignment(.trailing)
                    Text("KB/s")
                }
                HStack {
                    text("settings.disk_threshold")
                    Spacer()
                    TextField("", value: Binding(
                        get: { Int(cfg.diskThresholdBytesPerSec / 1024) },
                        set: { cfg.diskThresholdBytesPerSec = Double(max(1, $0)) * 1024 }
                    ), format: .number)
                    .frame(width: 80)
                    .multilineTextAlignment(.trailing)
                    Text("KB/s")
                }
            }
            Section {
                text("settings.threshold_footnote")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }

    private func listSection(
        titleKey: String,
        items: Binding<[String]>,
        newItem: Binding<String>,
        placeholderKey: String
    ) -> some View {
        let trimmed = newItem.wrappedValue.trimmingCharacters(in: .whitespaces)
        let canAdd = !trimmed.isEmpty && !items.wrappedValue.contains(trimmed)

        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                text(titleKey).font(.headline)
                Spacer()
                Text(f("settings.rules.count_format", items.wrappedValue.count))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(Color(nsColor: .separatorColor).opacity(0.18)))
            }

            HStack(spacing: 8) {
                TextField(s(placeholderKey), text: newItem)
                    .textFieldStyle(.roundedBorder)
                    .submitLabel(.done)
                    .onSubmit {
                        addListItem(items: items, newItem: newItem)
                    }
                Button {
                    addListItem(items: items, newItem: newItem)
                } label: {
                    Label(s("settings.add"), systemImage: "plus")
                }
                .buttonStyle(.borderedProminent)
                .disabled(!canAdd)
            }

            Divider()

            if items.wrappedValue.isEmpty {
                HStack(spacing: 8) {
                    Image(systemName: "tray")
                        .foregroundStyle(.secondary)
                    text("settings.empty")
                        .foregroundStyle(.secondary)
                        .font(.callout)
                    Spacer()
                }
                .padding(.vertical, 10)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 6) {
                        ForEach(items.wrappedValue, id: \.self) { item in
                            HStack {
                                Text(item).font(.system(.body, design: .monospaced))
                                Spacer()
                                Button {
                                    items.wrappedValue.removeAll { $0 == item }
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundStyle(.secondary)
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel(f("settings.remove_format", item))
                            }
                            .padding(.vertical, 6)
                            .padding(.horizontal, 10)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(Color(nsColor: .textBackgroundColor))
                            )
                        }
                    }
                }
                .frame(maxHeight: 180)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color(nsColor: .separatorColor).opacity(0.35), lineWidth: 1)
        )
    }

    private func addListItem(items: Binding<[String]>, newItem: Binding<String>) {
        let trimmed = newItem.wrappedValue.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        var arr = items.wrappedValue
        guard !arr.contains(trimmed) else { return }
        arr.append(trimmed)
        arr.sort()
        items.wrappedValue = arr
        newItem.wrappedValue = ""
    }

    private func setLaunchAtLogin(_ enabled: Bool) {
        do {
            try LaunchAtLoginManager.setEnabled(enabled)
            launchAtLoginError = nil
            cfg.launchAtLogin = enabled
        } catch {
            cfg.launchAtLogin = LaunchAtLoginManager.isEnabled
            launchAtLoginError = error.localizedDescription
        }
    }
}

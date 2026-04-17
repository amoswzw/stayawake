import Foundation

enum AppLanguage: String, CaseIterable, Codable, Identifiable {
    case system
    case english
    case simplifiedChinese
    case traditionalChinese
    case japanese
    case korean
    case french
    case german
    case spanish

    var id: String { rawValue }

    var titleKey: String {
        switch self {
        case .system: return "settings.language.system"
        case .english: return "settings.language.english"
        case .simplifiedChinese: return "settings.language.simplified_chinese"
        case .traditionalChinese: return "settings.language.traditional_chinese"
        case .japanese: return "settings.language.japanese"
        case .korean: return "settings.language.korean"
        case .french: return "settings.language.french"
        case .german: return "settings.language.german"
        case .spanish: return "settings.language.spanish"
        }
    }

    var lprojName: String? {
        switch self {
        case .system: return nil
        case .english: return "en"
        case .simplifiedChinese: return "zh-Hans"
        case .traditionalChinese: return "zh-Hant"
        case .japanese: return "ja"
        case .korean: return "ko"
        case .french: return "fr"
        case .german: return "de"
        case .spanish: return "es"
        }
    }
}

struct Config: Codable, Equatable {
    var sampleIntervalSeconds: TimeInterval = 15
    var idleThresholdSeconds: TimeInterval = 600          // 10 min
    var cpuThreshold: Double = 0.30                       // 30% any core
    var networkThresholdBytesPerSec: Double = 50 * 1024
    var diskThresholdBytesPerSec: Double = 1 * 1024 * 1024
    var cooldownSeconds: TimeInterval = 120
    var launchAtLogin: Bool = false
    var language: AppLanguage = .system
    var taskProcessNames: Set<String> = [
        "xcodebuild", "clang", "swift", "swift-frontend",
        "cc", "gcc", "g++", "make", "cmake", "ninja",
        "ffmpeg", "ffprobe", "HandBrakeCLI", "x264", "x265",
        "rsync", "scp", "curl", "wget", "aria2c", "yt-dlp",
        "python", "python3", "node", "deno", "bun",
        "docker", "dockerd", "qemu-system-x86_64",
        "go", "cargo", "rustc", "mvn", "gradle",
        "brew", "apt", "yum", "dnf",
        "tar", "gzip", "zstd", "xz",
        "mysqldump", "pg_dump", "pg_restore",
        "claude", "codex", "gemini", "opencode"
    ]
    var workBundleIDs: Set<String> = [
        "com.apple.dt.Xcode",
        "com.microsoft.VSCode",
        "com.todesktop.230313mzl4w4u92",        // Cursor
        "com.jetbrains.intellij",
        "com.jetbrains.pycharm",
        "com.jetbrains.goland",
        "com.jetbrains.WebStorm",
        "com.jetbrains.CLion",
        "com.jetbrains.AppCode",
        "com.jetbrains.rider",
        "com.apple.Terminal",
        "com.googlecode.iterm2",
        "dev.warp.Warp-Stable",
        "net.kovidgoyal.kitty",
        "com.github.wez.wezterm",
        "com.sublimetext.4",
        "com.adobe.Photoshop",
        "com.adobe.Premiere",
        "com.adobe.AfterEffects",
        "com.apple.FinalCut",
        "com.apple.logic10",
        "com.blackmagic-design.DaVinciResolve",
        "com.figma.Desktop"
    ]
    var blacklistBundleIDs: Set<String> = []

    init() {}

    init(from decoder: Decoder) throws {
        let base = Config()
        let c = try decoder.container(keyedBy: CodingKeys.self)
        sampleIntervalSeconds = try c.decodeIfPresent(TimeInterval.self, forKey: .sampleIntervalSeconds) ?? base.sampleIntervalSeconds
        idleThresholdSeconds = try c.decodeIfPresent(TimeInterval.self, forKey: .idleThresholdSeconds) ?? base.idleThresholdSeconds
        cpuThreshold = try c.decodeIfPresent(Double.self, forKey: .cpuThreshold) ?? base.cpuThreshold
        networkThresholdBytesPerSec = try c.decodeIfPresent(Double.self, forKey: .networkThresholdBytesPerSec) ?? base.networkThresholdBytesPerSec
        diskThresholdBytesPerSec = try c.decodeIfPresent(Double.self, forKey: .diskThresholdBytesPerSec) ?? base.diskThresholdBytesPerSec
        cooldownSeconds = try c.decodeIfPresent(TimeInterval.self, forKey: .cooldownSeconds) ?? base.cooldownSeconds
        launchAtLogin = try c.decodeIfPresent(Bool.self, forKey: .launchAtLogin) ?? base.launchAtLogin
        language = try c.decodeIfPresent(AppLanguage.self, forKey: .language) ?? base.language
        taskProcessNames = try c.decodeIfPresent(Set<String>.self, forKey: .taskProcessNames) ?? base.taskProcessNames
        workBundleIDs = try c.decodeIfPresent(Set<String>.self, forKey: .workBundleIDs) ?? base.workBundleIDs
        blacklistBundleIDs = try c.decodeIfPresent(Set<String>.self, forKey: .blacklistBundleIDs) ?? base.blacklistBundleIDs
    }
}

final class ConfigStore {
    static let shared = ConfigStore()
    static let didChangeNotification = Notification.Name("stayawake.config.didChange")

    private let key = "stayawake.config.v1"
    private let defaults: UserDefaults
    private(set) var config: Config {
        didSet {
            save()
            NotificationCenter.default.post(name: Self.didChangeNotification, object: self)
        }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: key),
           let cfg = try? JSONDecoder().decode(Config.self, from: data) {
            self.config = cfg
        } else {
            self.config = Config()
        }
    }

    func update(_ mutate: (inout Config) -> Void) {
        var cfg = config
        mutate(&cfg)
        guard cfg != config else { return }
        config = cfg
    }

    private func save() {
        if let data = try? JSONEncoder().encode(config) {
            defaults.set(data, forKey: key)
        }
    }
}

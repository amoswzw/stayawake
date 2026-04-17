import Foundation

enum ProbeFailure: String, Hashable, Sendable {
    case cpu
    case network
    case disk
    case audio
    case fullscreen
    case idle
    case power
}

struct Context: Equatable, Sendable {
    var frontmostBundleID: String?
    var frontmostName: String?
    var runningProcessNames: Set<String>
    var maxCoreCPU: Double
    var networkRateBytesPerSec: Double
    var diskRateBytesPerSec: Double
    var audioActive: Bool
    var fullscreenActive: Bool
    var fullscreenOwnerBundleID: String?
    var idleSeconds: TimeInterval
    var onBattery: Bool
    var thermalState: ProcessInfo.ThermalState
    var probeFailures: Set<ProbeFailure>

    static let empty = Context(
        frontmostBundleID: nil,
        frontmostName: nil,
        runningProcessNames: [],
        maxCoreCPU: 0,
        networkRateBytesPerSec: 0,
        diskRateBytesPerSec: 0,
        audioActive: false,
        fullscreenActive: false,
        fullscreenOwnerBundleID: nil,
        idleSeconds: 0,
        onBattery: false,
        thermalState: .nominal,
        probeFailures: []
    )
}

struct TaskSignal: Equatable, Sendable {
    var hasActiveProcess: Bool
    var isResourceBusy: Bool
    var hasForegroundWork: Bool
    var fullscreenActive: Bool
    var audioActive: Bool
    var isUserIdle: Bool
    var hasRecentUserInput: Bool
    var hasUncertainSignals: Bool
}

enum Action: Equatable, Sendable {
    case keepAwake(reason: String)
    case allowSleep(reason: String)
    case noChange

    var reasonText: String {
        switch self {
        case .keepAwake(let r): return r
        case .allowSleep(let r): return r
        case .noChange: return ""
        }
    }
}

enum ManualOverride: Equatable, Sendable {
    case timed(until: Date)
    case untilOff
}

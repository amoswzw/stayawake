import Foundation
import CoreAudio

enum AudioProbe {
    private static let deviceCacheTTL: TimeInterval = 300
    private static let cacheLock = NSLock()
    private static var cachedDevices: [AudioDeviceID]?
    private static var cachedAt: Date?

    static func isAnyOutputRunning(now: Date = Date()) -> Bool? {
        guard let devices = cachedAllDevices(now: now) else { return nil }
        for id in devices where deviceIsRunning(id) {
            return true
        }
        return false
    }

    private static func cachedAllDevices(now: Date) -> [AudioDeviceID]? {
        cacheLock.lock()
        defer { cacheLock.unlock() }

        if let cachedDevices, let cachedAt,
           now.timeIntervalSince(cachedAt) < deviceCacheTTL {
            return cachedDevices
        }

        guard let devices = allDevices() else {
            return cachedDevices
        }

        cachedDevices = devices
        cachedAt = now
        return devices
    }

    private static func allDevices() -> [AudioDeviceID]? {
        var addr = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var size: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(
            AudioObjectID(kAudioObjectSystemObject),
            &addr, 0, nil, &size
        ) == noErr else { return nil }
        guard size > 0 else { return [] }

        let count = Int(size) / MemoryLayout<AudioDeviceID>.size
        var ids = [AudioDeviceID](repeating: 0, count: count)
        let rc = ids.withUnsafeMutableBufferPointer { buf -> OSStatus in
            AudioObjectGetPropertyData(
                AudioObjectID(kAudioObjectSystemObject),
                &addr, 0, nil, &size, buf.baseAddress!
            )
        }
        guard rc == noErr else { return nil }
        return ids
    }

    private static func deviceIsRunning(_ device: AudioDeviceID) -> Bool {
        var addr = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyDeviceIsRunningSomewhere,
            mScope: kAudioObjectPropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        var running: UInt32 = 0
        var size = UInt32(MemoryLayout<UInt32>.size)
        let rc = AudioObjectGetPropertyData(device, &addr, 0, nil, &size, &running)
        return rc == noErr && running != 0
    }
}

import Foundation

final class SignalCollector {
    private let cpu = CPUProbe()
    private let net = NetworkProbe()
    private let disk = DiskProbe()

    private var cpuWindow = SlidingWindow(duration: 60)
    private var netWindow = SlidingWindow(duration: 60)
    private var diskWindow = SlidingWindow(duration: 60)

    func sample(taskProcessNames: Set<String>) -> Context {
        let now = Date()
        var failures = Set<ProbeFailure>()

        let cpuInstant = cpu.sampleMaxCoreUsage() ?? {
            failures.insert(.cpu)
            return 0
        }()
        let netInstant = net.sampleRateBytesPerSec() ?? {
            failures.insert(.network)
            return 0
        }()
        let diskInstant = disk.sampleRateBytesPerSec() ?? {
            failures.insert(.disk)
            return 0
        }()

        cpuWindow.add(cpuInstant, at: now)
        netWindow.add(netInstant, at: now)
        diskWindow.add(diskInstant, at: now)

        let cpuP75 = cpuWindow.percentile(0.75)
        let netP75 = netWindow.percentile(0.75)
        let diskP75 = diskWindow.percentile(0.75)

        let front = FrontmostAppProbe.current()
        let procs = ProcessProbe.runningNames(matching: taskProcessNames)
        let audio = AudioProbe.isAnyOutputRunning() ?? {
            failures.insert(.audio)
            return false
        }()
        let fullscreen = FullscreenProbe.current() ?? {
            failures.insert(.fullscreen)
            return FullscreenProbe.Info(active: false, ownerBundleID: nil)
        }()
        let idle = IdleProbe.secondsSinceInput() ?? {
            failures.insert(.idle)
            return 0
        }()
        let battery = PowerProbe.isOnBattery() ?? {
            failures.insert(.power)
            return false
        }()
        let thermal = ProcessInfo.processInfo.thermalState

        return Context(
            frontmostBundleID: front.bundleID,
            frontmostName: front.name,
            runningProcessNames: procs,
            maxCoreCPU: cpuP75,
            networkRateBytesPerSec: netP75,
            diskRateBytesPerSec: diskP75,
            audioActive: audio,
            fullscreenActive: fullscreen.active,
            fullscreenOwnerBundleID: fullscreen.ownerBundleID,
            idleSeconds: idle,
            onBattery: battery,
            thermalState: thermal,
            probeFailures: failures
        )
    }
}

import Foundation
import Darwin.Mach

final class CPUProbe {
    private var prev: [(user: UInt64, system: UInt64, idle: UInt64, nice: UInt64)] = []

    func sampleMaxCoreUsage() -> Double? {
        var cpuCount: natural_t = 0
        var infoArray: processor_info_array_t?
        var infoCount: mach_msg_type_number_t = 0
        let kr = host_processor_info(
            mach_host_self(),
            PROCESSOR_CPU_LOAD_INFO,
            &cpuCount,
            &infoArray,
            &infoCount
        )
        guard kr == KERN_SUCCESS, let info = infoArray else {
            prev = []
            return nil
        }
        defer {
            let addr = vm_address_t(bitPattern: UnsafePointer(info))
            vm_deallocate(
                mach_task_self_,
                addr,
                vm_size_t(infoCount) * vm_size_t(MemoryLayout<integer_t>.size)
            )
        }

        let stateCount = Int(CPU_STATE_MAX)
        var current: [(user: UInt64, system: UInt64, idle: UInt64, nice: UInt64)] = []
        current.reserveCapacity(Int(cpuCount))
        for i in 0..<Int(cpuCount) {
            let base = i * stateCount
            current.append((
                UInt64(UInt32(bitPattern: info[base + Int(CPU_STATE_USER)])),
                UInt64(UInt32(bitPattern: info[base + Int(CPU_STATE_SYSTEM)])),
                UInt64(UInt32(bitPattern: info[base + Int(CPU_STATE_IDLE)])),
                UInt64(UInt32(bitPattern: info[base + Int(CPU_STATE_NICE)]))
            ))
        }

        defer { prev = current }
        guard prev.count == current.count, !prev.isEmpty else { return 0 }

        var maxUsage = 0.0
        for i in 0..<current.count {
            let dUser = current[i].user &- prev[i].user
            let dSys = current[i].system &- prev[i].system
            let dIdle = current[i].idle &- prev[i].idle
            let dNice = current[i].nice &- prev[i].nice
            let nonIdle = dUser &+ dSys &+ dNice
            let total = nonIdle &+ dIdle
            guard total > 0 else { continue }
            let usage = Double(nonIdle) / Double(total)
            if usage > maxUsage { maxUsage = usage }
        }
        return maxUsage
    }
}

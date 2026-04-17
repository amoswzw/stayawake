import Foundation
import IOKit.ps

enum PowerProbe {
    static func isOnBattery() -> Bool? {
        guard let blob = IOPSCopyPowerSourcesInfo()?.takeRetainedValue() else {
            return nil
        }
        guard let typeCF = IOPSGetProvidingPowerSourceType(blob)?.takeUnretainedValue() else {
            return nil
        }
        let type = typeCF as String
        return type == kIOPSBatteryPowerValue
    }
}

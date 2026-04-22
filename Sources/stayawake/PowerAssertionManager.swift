import Foundation
import IOKit
import IOKit.pwr_mgt

final class PowerAssertionManager {
    private var assertionID: IOPMAssertionID = IOPMAssertionID(0)
    private var currentReason: String?
    private var currentPreventsDisplaySleep: Bool = false

    var isAwake: Bool { assertionID != 0 }
    var reason: String? { currentReason }
    var preventsDisplaySleep: Bool { currentPreventsDisplaySleep }

    @discardableResult
    func ensureAwake(reason: String, preventDisplaySleep: Bool) -> Bool {
        if isAwake {
            if currentPreventsDisplaySleep == preventDisplaySleep {
                currentReason = reason
                return true
            }
            IOPMAssertionRelease(assertionID)
            assertionID = IOPMAssertionID(0)
            currentReason = nil
            currentPreventsDisplaySleep = false
        }
        let type: CFString = preventDisplaySleep
            ? kIOPMAssertionTypePreventUserIdleDisplaySleep as CFString
            : kIOPMAssertionTypePreventUserIdleSystemSleep as CFString
        var id: IOPMAssertionID = IOPMAssertionID(0)
        let rc = IOPMAssertionCreateWithName(
            type,
            IOPMAssertionLevel(kIOPMAssertionLevelOn),
            reason as CFString,
            &id
        )
        if rc == kIOReturnSuccess {
            assertionID = id
            currentReason = reason
            currentPreventsDisplaySleep = preventDisplaySleep
            return true
        }
        return false
    }

    func release() {
        guard isAwake else { return }
        IOPMAssertionRelease(assertionID)
        assertionID = IOPMAssertionID(0)
        currentReason = nil
        currentPreventsDisplaySleep = false
    }

    deinit { release() }
}

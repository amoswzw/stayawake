import Foundation
import IOKit
import IOKit.pwr_mgt

final class PowerAssertionManager {
    private var assertionID: IOPMAssertionID = IOPMAssertionID(0)
    private var currentReason: String?

    var isAwake: Bool { assertionID != 0 }
    var reason: String? { currentReason }

    @discardableResult
    func ensureAwake(reason: String) -> Bool {
        if isAwake {
            currentReason = reason
            return true
        }
        var id: IOPMAssertionID = IOPMAssertionID(0)
        let rc = IOPMAssertionCreateWithName(
            kIOPMAssertionTypePreventUserIdleSystemSleep as CFString,
            IOPMAssertionLevel(kIOPMAssertionLevelOn),
            reason as CFString,
            &id
        )
        if rc == kIOReturnSuccess {
            assertionID = id
            currentReason = reason
            return true
        }
        return false
    }

    func release() {
        guard isAwake else { return }
        IOPMAssertionRelease(assertionID)
        assertionID = IOPMAssertionID(0)
        currentReason = nil
    }

    deinit { release() }
}

import Foundation
import IOKit.pwr_mgt

enum PowerAssertionState: Equatable {
    case active
    case batteryBlocked
    case acPowerOnly
    case stopped
    case failed(IOReturn)
}

final class PowerAssertionController {
    private var assertionID: IOPMAssertionID = 0

    var isActive: Bool {
        assertionID != 0
    }

    @discardableResult
    func acquire() -> PowerAssertionState {
        if isActive {
            return .active
        }

        var newAssertionID = IOPMAssertionID(0)
        let result = IOPMAssertionCreateWithName(
            kIOPMAssertionTypePreventSystemSleep as CFString,
            IOPMAssertionLevel(kIOPMAssertionLevelOn),
            "LidStay prevents system sleep while allowing display sleep." as CFString,
            &newAssertionID
        )

        guard result == kIOReturnSuccess else {
            assertionID = 0
            return .failed(result)
        }

        assertionID = newAssertionID
        return .active
    }

    func release() {
        guard isActive else {
            return
        }

        IOPMAssertionRelease(assertionID)
        assertionID = 0
    }

    deinit {
        release()
    }
}

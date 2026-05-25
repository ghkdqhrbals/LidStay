import Foundation
import IOKit
import IOKit.pwr_mgt

enum PowerAssertionState: Equatable {
    case active
    case batteryBlocked
    case acPowerOnly
    case stopped
    case failed(IOReturn)
}

final class PowerAssertionController {
    private let setClamshellSleepStateSelector: UInt32 = 12
    private let brightnessController: ClosedLidBrightnessController
    private var systemAssertionID: IOPMAssertionID = 0
    private var displayAssertionID: IOPMAssertionID = 0
    private var clamshellSleepDisabled = false

    init(brightnessController: ClosedLidBrightnessController = ClosedLidBrightnessController()) {
        self.brightnessController = brightnessController
    }

    var isActive: Bool {
        systemAssertionID != 0 && displayAssertionID != 0
    }

    @discardableResult
    func acquire() -> PowerAssertionState {
        if isActive {
            return .active
        }

        release()

        var newSystemAssertionID = IOPMAssertionID(0)
        let systemResult = IOPMAssertionCreateWithName(
            kIOPMAssertionTypePreventSystemSleep as CFString,
            IOPMAssertionLevel(kIOPMAssertionLevelOn),
            "LidStay prevents system sleep." as CFString,
            &newSystemAssertionID
        )

        guard systemResult == kIOReturnSuccess else {
            return .failed(systemResult)
        }

        var newDisplayAssertionID = IOPMAssertionID(0)
        let displayResult = IOPMAssertionCreateWithName(
            kIOPMAssertionTypePreventUserIdleDisplaySleep as CFString,
            IOPMAssertionLevel(kIOPMAssertionLevelOn),
            "LidStay keeps the display awake while active." as CFString,
            &newDisplayAssertionID
        )

        guard displayResult == kIOReturnSuccess else {
            IOPMAssertionRelease(newSystemAssertionID)
            return .failed(displayResult)
        }

        systemAssertionID = newSystemAssertionID
        displayAssertionID = newDisplayAssertionID
        return .active
    }

    func release() {
        _ = brightnessController.restoreIfNeeded(reason: "sleep prevention released")

        if displayAssertionID != 0 {
            IOPMAssertionRelease(displayAssertionID)
            displayAssertionID = 0
        }

        if systemAssertionID != 0 {
            IOPMAssertionRelease(systemAssertionID)
            systemAssertionID = 0
        }
    }

    @discardableResult
    func setClamshellSleepDisabled(_ disabled: Bool, force: Bool = false) -> IOReturn? {
        guard force || disabled != clamshellSleepDisabled else {
            return nil
        }

        let rootDomain = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("IOPMrootDomain"))
        guard rootDomain != IO_OBJECT_NULL else {
            return kIOReturnNotFound
        }
        defer {
            IOObjectRelease(rootDomain)
        }

        var connection = io_connect_t()
        let openResult = IOServiceOpen(rootDomain, mach_task_self_, 0, &connection)
        guard openResult == kIOReturnSuccess else {
            return openResult
        }
        defer {
            IOServiceClose(connection)
        }

        var input: [UInt64] = [disabled ? 1 : 0]
        let result = IOConnectCallScalarMethod(
            connection,
            setClamshellSleepStateSelector,
            &input,
            UInt32(input.count),
            nil,
            nil
        )

        if result == kIOReturnSuccess {
            clamshellSleepDisabled = disabled
        }

        return result
    }

    @discardableResult
    func restoreSystemSleepState() -> IOReturn? {
        let result = setClamshellSleepDisabled(false, force: true)
        _ = brightnessController.restoreIfNeeded(reason: "app startup safety reset")
        release()
        return result
    }

    func updateDisplayBrightnessForClosedLid(active: Bool) -> PowerControllerEvent? {
        brightnessController.update(active: active)
    }

    deinit {
        _ = setClamshellSleepDisabled(false, force: true)
        release()
    }
}

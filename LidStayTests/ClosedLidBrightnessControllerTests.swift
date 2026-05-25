import XCTest

final class ClosedLidBrightnessControllerTests: XCTestCase {
    func testDimsToMinimumOnceWhenLidCloses() {
        let hardware = FakeClosedLidBrightnessHardware()
        hardware.clamshellClosed = true
        hardware.brightness = 0.72
        let controller = ClosedLidBrightnessController(hardware: hardware)

        let event = controller.update(active: true)
        let repeatedEvent = controller.update(active: true)

        XCTAssertEqual(event, PowerControllerEvent(
            kind: .closedLidBrightnessDimmed,
            detail: "Set display brightness to minimum on closed lid; saved 0.72",
            succeeded: true
        ))
        XCTAssertNil(repeatedEvent)
        XCTAssertEqual(hardware.setBrightnessValues, [0])
    }

    func testRestoresSavedBrightnessWhenLidOpens() {
        let hardware = FakeClosedLidBrightnessHardware()
        hardware.clamshellClosed = true
        hardware.brightness = 0.35
        let controller = ClosedLidBrightnessController(hardware: hardware)

        _ = controller.update(active: true)
        hardware.clamshellClosed = false
        let event = controller.update(active: true)

        XCTAssertEqual(event, PowerControllerEvent(
            kind: .brightnessRestored,
            detail: "Restore display brightness to 0.35 on lid opened",
            succeeded: true
        ))
        XCTAssertEqual(hardware.setBrightnessValues, [0, 0.35])
    }

    func testRestoresSavedBrightnessWhenSessionStops() {
        let hardware = FakeClosedLidBrightnessHardware()
        hardware.clamshellClosed = true
        hardware.brightness = 0.91
        let controller = ClosedLidBrightnessController(hardware: hardware)

        _ = controller.update(active: true)
        let event = controller.update(active: false)

        XCTAssertEqual(event, PowerControllerEvent(
            kind: .brightnessRestored,
            detail: "Restore display brightness to 0.91 on session inactive",
            succeeded: true
        ))
        XCTAssertEqual(hardware.setBrightnessValues, [0, 0.91])
    }

    func testRestoresLastOpenBrightnessWhenClosedReadIsAlreadyZero() {
        let hardware = FakeClosedLidBrightnessHardware()
        hardware.clamshellClosed = false
        hardware.brightness = 0.74
        let controller = ClosedLidBrightnessController(hardware: hardware)

        XCTAssertNil(controller.update(active: true))

        hardware.clamshellClosed = true
        hardware.brightness = 0
        let dimEvent = controller.update(active: true)
        hardware.clamshellClosed = false
        let restoreEvent = controller.update(active: true)

        XCTAssertEqual(dimEvent, PowerControllerEvent(
            kind: .closedLidBrightnessDimmed,
            detail: "Set display brightness to minimum on closed lid; saved 0.74",
            succeeded: true
        ))
        XCTAssertEqual(restoreEvent, PowerControllerEvent(
            kind: .brightnessRestored,
            detail: "Restore display brightness to 0.74 on lid opened",
            succeeded: true
        ))
        XCTAssertEqual(hardware.setBrightnessValues, [0, 0.74])
    }

    func testFallsBackToDefaultBrightnessWhenClosedReadIsZeroWithoutOpenSample() {
        let hardware = FakeClosedLidBrightnessHardware()
        hardware.clamshellClosed = true
        hardware.brightness = 0
        let controller = ClosedLidBrightnessController(hardware: hardware)

        let dimEvent = controller.update(active: true)
        hardware.clamshellClosed = false
        let restoreEvent = controller.update(active: true)

        XCTAssertEqual(dimEvent, PowerControllerEvent(
            kind: .closedLidBrightnessDimmed,
            detail: "Set display brightness to minimum on closed lid; saved 0.50",
            succeeded: true
        ))
        XCTAssertEqual(restoreEvent, PowerControllerEvent(
            kind: .brightnessRestored,
            detail: "Restore display brightness to 0.50 on lid opened",
            succeeded: true
        ))
        XCTAssertEqual(hardware.setBrightnessValues, [0, 0.5])
    }

    func testDoesNothingWhenClamshellStateIsUnavailable() {
        let hardware = FakeClosedLidBrightnessHardware()
        hardware.clamshellClosed = nil
        let controller = ClosedLidBrightnessController(hardware: hardware)

        let event = controller.update(active: true)

        XCTAssertNil(event)
        XCTAssertTrue(hardware.setBrightnessValues.isEmpty)
    }

    func testDimsBuiltInDisplayButDoesNotRequestScreenSaverWhenExternalDisplayIsConnected() {
        let hardware = FakeClosedLidBrightnessHardware()
        hardware.clamshellClosed = true
        hardware.externalDisplayConnected = true
        hardware.brightness = 0.66
        let controller = ClosedLidBrightnessController(hardware: hardware)

        let event = controller.update(active: true)
        let repeatedEvent = controller.update(active: true)

        XCTAssertEqual(event, PowerControllerEvent(
            kind: .closedLidBrightnessDimmedWithExternalDisplay,
            detail: "Set built-in display brightness to minimum on closed lid with external display; saved 0.66",
            succeeded: true
        ))
        XCTAssertNil(repeatedEvent)
        XCTAssertEqual(hardware.setBrightnessValues, [0])
    }

    func testKeepsBrightnessDimmedIfExternalDisplayConnectsAfterClosedLidDim() {
        let hardware = FakeClosedLidBrightnessHardware()
        hardware.clamshellClosed = true
        hardware.brightness = 0.58
        let controller = ClosedLidBrightnessController(hardware: hardware)

        _ = controller.update(active: true)
        hardware.externalDisplayConnected = true
        let event = controller.update(active: true)

        XCTAssertNil(event)
        XCTAssertEqual(hardware.setBrightnessValues, [0])
    }

    func testReportsClosedLidBrightnessUnavailableOnlyOnce() {
        let hardware = FakeClosedLidBrightnessHardware()
        hardware.clamshellClosed = true
        hardware.externalDisplayConnected = true
        hardware.readBrightnessError = BrightnessHardwareError(message: "built-in display is not online")
        let controller = ClosedLidBrightnessController(hardware: hardware)

        let firstEvent = controller.update(active: true)
        let repeatedEvent = controller.update(active: true)

        XCTAssertEqual(firstEvent, PowerControllerEvent(
            kind: .closedLidBrightnessUnavailable,
            detail: "Built-in display brightness service unavailable while lid is closed: built-in display is not online",
            succeeded: true
        ))
        XCTAssertNil(repeatedEvent)
        XCTAssertTrue(hardware.setBrightnessValues.isEmpty)
    }

    func testClosedLidBrightnessUnavailableCanReportAgainAfterLidOpens() {
        let hardware = FakeClosedLidBrightnessHardware()
        hardware.clamshellClosed = true
        hardware.readBrightnessError = BrightnessHardwareError(message: "built-in display is not online")
        let controller = ClosedLidBrightnessController(hardware: hardware)

        _ = controller.update(active: true)
        hardware.clamshellClosed = false
        hardware.readBrightnessError = nil
        XCTAssertNil(controller.update(active: true))

        hardware.clamshellClosed = true
        hardware.readBrightnessError = BrightnessHardwareError(message: "built-in display is not online")
        let event = controller.update(active: true)

        XCTAssertEqual(event, PowerControllerEvent(
            kind: .closedLidBrightnessUnavailable,
            detail: "Built-in display brightness service unavailable while lid is closed: built-in display is not online",
            succeeded: true
        ))
    }

    func testDoesNotMarkDimmedWhenMinimumBrightnessWriteFails() {
        let hardware = FakeClosedLidBrightnessHardware()
        hardware.clamshellClosed = true
        hardware.brightness = 0.6
        hardware.nextSetBrightnessError = BrightnessHardwareError(message: "write failed")
        let controller = ClosedLidBrightnessController(hardware: hardware)

        let failedEvent = controller.update(active: true)
        let retryEvent = controller.update(active: true)

        XCTAssertEqual(failedEvent, PowerControllerEvent(
            kind: .brightnessFailed,
            detail: "Set display brightness to minimum failed: write failed",
            succeeded: false
        ))
        XCTAssertEqual(retryEvent, PowerControllerEvent(
            kind: .closedLidBrightnessDimmed,
            detail: "Set display brightness to minimum on closed lid; saved 0.60",
            succeeded: true
        ))
        XCTAssertEqual(hardware.setBrightnessValues, [0, 0])
    }

    func testRestoreFailureKeepsSavedBrightnessAndRetries() {
        let hardware = FakeClosedLidBrightnessHardware()
        hardware.clamshellClosed = true
        hardware.brightness = 0.42
        let controller = ClosedLidBrightnessController(hardware: hardware)

        _ = controller.update(active: true)
        hardware.nextSetBrightnessError = BrightnessHardwareError(message: "restore failed")
        let failedEvent = controller.update(active: false)
        let retryEvent = controller.update(active: false)

        XCTAssertEqual(failedEvent, PowerControllerEvent(
            kind: .brightnessFailed,
            detail: "Restore display brightness failed on session inactive: restore failed",
            succeeded: false
        ))
        XCTAssertEqual(retryEvent, PowerControllerEvent(
            kind: .brightnessRestored,
            detail: "Restore display brightness to 0.42 on session inactive",
            succeeded: true
        ))
        XCTAssertEqual(hardware.setBrightnessValues, [0, 0.42, 0.42])
    }
}

private final class FakeClosedLidBrightnessHardware: ClosedLidBrightnessHardware {
    var clamshellClosed: Bool? = false
    var externalDisplayConnected = false
    var brightness: Float = 0.5
    var setBrightnessValues: [Float] = []
    var readBrightnessError: BrightnessHardwareError?
    var nextReadBrightnessError: BrightnessHardwareError?
    var nextSetBrightnessError: BrightnessHardwareError?

    func isClamshellClosed() -> Bool? {
        clamshellClosed
    }

    func hasExternalDisplayConnected() -> Bool {
        externalDisplayConnected
    }

    func readBrightness() -> Result<Float, BrightnessHardwareError> {
        if let readBrightnessError {
            return .failure(readBrightnessError)
        }

        if let nextReadBrightnessError {
            self.nextReadBrightnessError = nil
            return .failure(nextReadBrightnessError)
        }

        return .success(brightness)
    }

    func setBrightness(_ value: Float) -> BrightnessHardwareError? {
        setBrightnessValues.append(value)

        if let nextSetBrightnessError {
            self.nextSetBrightnessError = nil
            return nextSetBrightnessError
        }

        brightness = value
        return nil
    }
}

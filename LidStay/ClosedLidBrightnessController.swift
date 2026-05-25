import Foundation
import CoreGraphics
import Darwin
import IOKit
import IOKit.graphics

protocol ClosedLidBrightnessHardware {
    func isClamshellClosed() -> Bool?
    func hasExternalDisplayConnected() -> Bool
    func readBrightness() -> Result<Float, BrightnessHardwareError>
    func setBrightness(_ value: Float) -> BrightnessHardwareError?
}

struct BrightnessHardwareError: Error, Equatable {
    let message: String
}

enum PowerControllerEventKind: Equatable {
    case closedLidBrightnessDimmed
    case closedLidBrightnessDimmedWithExternalDisplay
    case closedLidBrightnessUnavailable
    case brightnessRestored
    case brightnessFailed
}

struct PowerControllerEvent: Equatable {
    let kind: PowerControllerEventKind
    let detail: String
    let succeeded: Bool
}

final class ClosedLidBrightnessController {
    private static let minimumRestorableBrightness: Float = 0.02
    private static let defaultRestoreBrightness: Float = 0.5

    private let hardware: ClosedLidBrightnessHardware
    private var savedBrightness: Float?
    private var lastKnownOpenBrightness: Float?
    private var dimmedForClosedLid = false
    private var brightnessUnavailableForClosedLidReported = false

    init(hardware: ClosedLidBrightnessHardware = IOKitClosedLidBrightnessHardware()) {
        self.hardware = hardware
    }

    func update(active: Bool) -> PowerControllerEvent? {
        guard active else {
            brightnessUnavailableForClosedLidReported = false
            return restoreIfNeeded(reason: "session inactive")
        }

        guard let isClosed = hardware.isClamshellClosed() else {
            return nil
        }

        if isClosed {
            return dimIfNeeded(externalDisplayConnected: hardware.hasExternalDisplayConnected())
        }

        brightnessUnavailableForClosedLidReported = false
        rememberOpenBrightnessIfAvailable()
        return restoreIfNeeded(reason: "lid opened")
    }

    func restoreIfNeeded(reason: String) -> PowerControllerEvent? {
        guard dimmedForClosedLid else {
            return nil
        }

        let brightnessToRestore = Self.restorableBrightness(savedBrightness)
            ?? lastKnownOpenBrightness
            ?? Self.defaultRestoreBrightness
        if let error = hardware.setBrightness(brightnessToRestore) {
            return PowerControllerEvent(
                kind: .brightnessFailed,
                detail: "Restore display brightness failed on \(reason): \(error.message)",
                succeeded: false
            )
        }

        savedBrightness = nil
        dimmedForClosedLid = false
        rememberOpenBrightness(brightnessToRestore)
        return PowerControllerEvent(
            kind: .brightnessRestored,
            detail: "Restore display brightness to \(Self.formatted(brightnessToRestore)) on \(reason)",
            succeeded: true
        )
    }

    private func dimIfNeeded(externalDisplayConnected: Bool) -> PowerControllerEvent? {
        guard !dimmedForClosedLid else {
            return nil
        }

        let currentBrightness: Float
        switch hardware.readBrightness() {
        case .success(let brightness):
            currentBrightness = brightness
        case .failure(let error):
            if brightnessUnavailableForClosedLidReported {
                return nil
            }

            brightnessUnavailableForClosedLidReported = true
            return PowerControllerEvent(
                kind: .closedLidBrightnessUnavailable,
                detail: "Built-in display brightness service unavailable while lid is closed: \(error.message)",
                succeeded: true
            )
        }

        let brightnessToSave = Self.restorableBrightness(currentBrightness)
            ?? lastKnownOpenBrightness
            ?? Self.defaultRestoreBrightness

        if let error = hardware.setBrightness(0) {
            return PowerControllerEvent(
                kind: .brightnessFailed,
                detail: "Set display brightness to minimum failed: \(error.message)",
                succeeded: false
            )
        }

        savedBrightness = brightnessToSave
        dimmedForClosedLid = true
        brightnessUnavailableForClosedLidReported = false
        return PowerControllerEvent(
            kind: externalDisplayConnected ? .closedLidBrightnessDimmedWithExternalDisplay : .closedLidBrightnessDimmed,
            detail: externalDisplayConnected
                ? "Set built-in display brightness to minimum on closed lid with external display; saved \(Self.formatted(brightnessToSave))"
                : "Set display brightness to minimum on closed lid; saved \(Self.formatted(brightnessToSave))",
            succeeded: true
        )
    }

    private func rememberOpenBrightnessIfAvailable() {
        guard !dimmedForClosedLid else {
            return
        }

        guard case .success(let brightness) = hardware.readBrightness() else {
            return
        }

        rememberOpenBrightness(brightness)
    }

    private func rememberOpenBrightness(_ brightness: Float) {
        guard let brightness = Self.restorableBrightness(brightness) else {
            return
        }

        lastKnownOpenBrightness = brightness
    }

    private static func restorableBrightness(_ value: Float?) -> Float? {
        guard let value, value > minimumRestorableBrightness else {
            return nil
        }

        return min(max(value, 0), 1)
    }

    private static func formatted(_ value: Float) -> String {
        String(format: "%.2f", value)
    }
}

struct IOKitClosedLidBrightnessHardware: ClosedLidBrightnessHardware {
    private let displayBrightnessParameter = "brightness" as CFString
    private let displayServices = DisplayServicesBrightnessClient()

    func isClamshellClosed() -> Bool? {
        let rootDomain = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("IOPMrootDomain"))
        guard rootDomain != IO_OBJECT_NULL else {
            return nil
        }
        defer {
            IOObjectRelease(rootDomain)
        }

        guard let value = IORegistryEntryCreateCFProperty(
            rootDomain,
            "AppleClamshellState" as CFString,
            kCFAllocatorDefault,
            0
        )?.takeRetainedValue() else {
            return nil
        }

        return value as? Bool
    }

    func readBrightness() -> Result<Float, BrightnessHardwareError> {
        guard Self.hasBuiltInDisplayOnline() else {
            return .failure(BrightnessHardwareError(message: "built-in display is not online"))
        }

        if let brightness = displayServices.readBrightness() {
            return .success(brightness)
        }

        guard !hasExternalDisplayConnected() else {
            return .failure(BrightnessHardwareError(message: "built-in DisplayServices brightness service not found with external display connected"))
        }

        guard let display = brightnessCapableDisplay() else {
            return .failure(BrightnessHardwareError(message: "built-in DisplayServices and IODisplay brightness services not found"))
        }
        defer {
            IOObjectRelease(display.service)
        }

        return .success(display.brightness)
    }

    func hasExternalDisplayConnected() -> Bool {
        Self.onlineDisplayIDs().contains { CGDisplayIsBuiltin($0) == 0 }
    }

    func setBrightness(_ value: Float) -> BrightnessHardwareError? {
        guard Self.hasBuiltInDisplayOnline() else {
            return BrightnessHardwareError(message: "built-in display is not online")
        }

        if displayServices.setBrightness(value) {
            return nil
        }

        guard !hasExternalDisplayConnected() else {
            return BrightnessHardwareError(message: "built-in DisplayServices brightness service not found with external display connected")
        }

        guard let display = brightnessCapableDisplay() else {
            return BrightnessHardwareError(message: "built-in DisplayServices and IODisplay brightness services not found")
        }
        defer {
            IOObjectRelease(display.service)
        }

        let result = IODisplaySetFloatParameter(
            display.service,
            IOOptionBits(0),
            displayBrightnessParameter,
            value
        )

        guard result == kIOReturnSuccess else {
            return BrightnessHardwareError(message: "IOReturn \(result)")
        }

        return nil
    }

    private static func hasBuiltInDisplayOnline() -> Bool {
        onlineDisplayIDs().contains { CGDisplayIsBuiltin($0) != 0 }
    }

    private static func onlineDisplayIDs() -> [CGDirectDisplayID] {
        var count: UInt32 = 0
        guard CGGetOnlineDisplayList(0, nil, &count) == .success, count > 0 else {
            return []
        }

        var displays = Array(repeating: CGDirectDisplayID(), count: Int(count))
        guard CGGetOnlineDisplayList(count, &displays, &count) == .success else {
            return []
        }

        return displays
    }

    private func brightnessCapableDisplay() -> (service: io_service_t, brightness: Float)? {
        var iterator = io_iterator_t()
        let result = IOServiceGetMatchingServices(
            kIOMainPortDefault,
            IOServiceMatching("IODisplayConnect"),
            &iterator
        )
        guard result == kIOReturnSuccess else {
            return nil
        }
        defer {
            IOObjectRelease(iterator)
        }

        while true {
            let service = IOIteratorNext(iterator)
            guard service != IO_OBJECT_NULL else {
                return nil
            }

            var brightness: Float = 0
            let readResult = IODisplayGetFloatParameter(
                service,
                IOOptionBits(0),
                displayBrightnessParameter,
                &brightness
            )

            if readResult == kIOReturnSuccess {
                return (service, brightness)
            }

            IOObjectRelease(service)
        }
    }
}

private final class DisplayServicesBrightnessClient {
    private typealias GetBrightness = @convention(c) (CGDirectDisplayID, UnsafeMutablePointer<Float>) -> Int32
    private typealias SetBrightness = @convention(c) (CGDirectDisplayID, Float) -> Int32

    private let handle: UnsafeMutableRawPointer?
    private let getBrightness: GetBrightness?
    private let setBrightness: SetBrightness?

    init() {
        let frameworkPath = "/System/Library/PrivateFrameworks/DisplayServices.framework/DisplayServices"
        handle = dlopen(frameworkPath, RTLD_LAZY)

        if let handle,
           let symbol = dlsym(handle, "DisplayServicesGetBrightness") {
            getBrightness = unsafeBitCast(symbol, to: GetBrightness.self)
        } else {
            getBrightness = nil
        }

        if let handle,
           let symbol = dlsym(handle, "DisplayServicesSetBrightness") {
            setBrightness = unsafeBitCast(symbol, to: SetBrightness.self)
        } else {
            setBrightness = nil
        }
    }

    deinit {
        if let handle {
            dlclose(handle)
        }
    }

    func readBrightness() -> Float? {
        guard let getBrightness else {
            return nil
        }

        for displayID in candidateDisplayIDs() {
            var brightness: Float = 0
            let result = getBrightness(displayID, &brightness)
            if result == 0 {
                return brightness
            }
        }

        return nil
    }

    func setBrightness(_ value: Float) -> Bool {
        guard let setBrightness else {
            return false
        }

        var didSet = false
        for displayID in candidateDisplayIDs() {
            let result = setBrightness(displayID, value)
            if result == 0 {
                didSet = true
            }
        }

        return didSet
    }

    private func candidateDisplayIDs() -> [CGDirectDisplayID] {
        var count: UInt32 = 0
        guard CGGetOnlineDisplayList(0, nil, &count) == .success, count > 0 else {
            return [CGMainDisplayID()]
        }

        var displays = Array(repeating: CGDirectDisplayID(), count: Int(count))
        guard CGGetOnlineDisplayList(count, &displays, &count) == .success else {
            return [CGMainDisplayID()]
        }

        let mainDisplayID = CGMainDisplayID()
        let sortedDisplays = displays.sorted { lhs, rhs in
            if lhs == mainDisplayID {
                return true
            }
            if rhs == mainDisplayID {
                return false
            }

            return CGDisplayIsBuiltin(lhs) != 0 && CGDisplayIsBuiltin(rhs) == 0
        }

        let builtinDisplays = sortedDisplays.filter { CGDisplayIsBuiltin($0) != 0 }
        return builtinDisplays
    }
}

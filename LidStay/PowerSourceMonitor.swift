import Foundation
import IOKit.ps

enum PowerSourceState: Equatable {
    case acPower
    case battery
    case unknown
}

struct PowerSourceSnapshot: Equatable {
    let state: PowerSourceState
    let batteryPercentage: Int?
}

final class PowerSourceMonitor {
    var onChange: ((PowerSourceSnapshot) -> Void)?

    private(set) var currentSnapshot: PowerSourceSnapshot = PowerSourceMonitor.readCurrentSnapshot()
    private var runLoopSource: CFRunLoopSource?

    func start() {
        stop()

        guard let source = IOPSNotificationCreateRunLoopSource({ context in
            guard let context else {
                return
            }

            let monitor = Unmanaged<PowerSourceMonitor>
                .fromOpaque(context)
                .takeUnretainedValue()
            monitor.refresh()
        }, UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque()))?.takeRetainedValue() else {
            return
        }

        runLoopSource = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .defaultMode)
    }

    func stop() {
        guard let source = runLoopSource else {
            return
        }

        CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .defaultMode)
        runLoopSource = nil
    }

    private func refresh() {
        let newSnapshot = Self.readCurrentSnapshot()
        guard newSnapshot != currentSnapshot else {
            return
        }

        currentSnapshot = newSnapshot
        onChange?(newSnapshot)
    }

    private static func readCurrentSnapshot() -> PowerSourceSnapshot {
        guard let info = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let sources = IOPSCopyPowerSourcesList(info)?.takeRetainedValue() as? [CFTypeRef] else {
            return PowerSourceSnapshot(state: .unknown, batteryPercentage: nil)
        }

        if sources.isEmpty {
            return PowerSourceSnapshot(state: .acPower, batteryPercentage: nil)
        }

        var sawBattery = false
        var batteryPercentage: Int?
        for source in sources {
            guard let description = IOPSGetPowerSourceDescription(info, source)?
                .takeUnretainedValue() as? [String: Any],
                  let sourceState = description[kIOPSPowerSourceStateKey] as? String else {
                continue
            }

            if let currentCapacity = description[kIOPSCurrentCapacityKey] as? Int,
               let maxCapacity = description[kIOPSMaxCapacityKey] as? Int,
               maxCapacity > 0 {
                batteryPercentage = Int((Double(currentCapacity) / Double(maxCapacity) * 100).rounded())
            }

            if sourceState == kIOPSACPowerValue {
                return PowerSourceSnapshot(state: .acPower, batteryPercentage: batteryPercentage)
            }

            if sourceState == kIOPSBatteryPowerValue {
                sawBattery = true
            }
        }

        return PowerSourceSnapshot(state: sawBattery ? .battery : .unknown, batteryPercentage: batteryPercentage)
    }

    deinit {
        stop()
    }
}

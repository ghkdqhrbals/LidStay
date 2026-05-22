import Foundation

extension Notification.Name {
    static let lidStayCLICommand = Notification.Name("com.ghkdqhrbals.LidStay.cli.command")
}

extension PowerAssertionState {
    var cliValue: String {
        switch self {
        case .active:
            return "active"
        case .batteryBlocked:
            return "paused-battery"
        case .acPowerOnly:
            return "waiting-power"
        case .stopped:
            return "off"
        case .failed:
            return "failed"
        }
    }
}

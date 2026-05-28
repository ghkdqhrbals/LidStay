import Foundation
import Network

struct NetworkRecoveryConfiguration: Equatable {
    var isEnabled: Bool
    var hotspotSSID: String
    var retryDelay: TimeInterval
    var shouldMonitor: Bool
}

enum NetworkRecoveryStatus: Equatable {
    case off
    case waitingForSSID
    case ready
    case monitoring
    case waitingToRetry(Int)
    case connecting
    case connected(String)
    case failed(String)
    case unavailable(String)
}

struct NetworkRecoveryEvent: Equatable {
    let detail: String
    let succeeded: Bool
}

@MainActor
final class NetworkRecoveryController {
    var onStatusChange: ((NetworkRecoveryStatus) -> Void)?
    var onEvent: ((NetworkRecoveryEvent) -> Void)?

    private let monitorQueue = DispatchQueue(label: "com.ghkdqhrbals.LidStay.network-recovery")
    private var monitor: NWPathMonitor?
    private var lastPath: NWPath?
    private var configuration = NetworkRecoveryConfiguration(
        isEnabled: false,
        hotspotSSID: "",
        retryDelay: 30,
        shouldMonitor: false
    )
    private var status: NetworkRecoveryStatus = .off
    private var retryTask: Task<Void, Never>?
    private var connectionTask: Task<Void, Never>?

    func update(configuration newConfiguration: NetworkRecoveryConfiguration) {
        guard newConfiguration != configuration else {
            return
        }

        configuration = newConfiguration
        evaluateCurrentState()
    }

    func stop() {
        cancelPendingWork()
        monitor?.cancel()
        monitor = nil
        lastPath = nil
        setStatus(.off)
    }

    private func evaluateCurrentState() {
        guard configuration.isEnabled else {
            stop()
            return
        }

        startMonitorIfNeeded()

        guard !configuration.hotspotSSID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            cancelPendingWork()
            setStatus(.waitingForSSID)
            return
        }

        guard configuration.shouldMonitor else {
            cancelPendingWork()
            setStatus(.ready)
            return
        }

        guard let lastPath else {
            setStatus(.monitoring)
            return
        }

        handlePath(lastPath)
    }

    private func startMonitorIfNeeded() {
        guard monitor == nil else {
            return
        }

        let monitor = NWPathMonitor()
        monitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor in
                self?.lastPath = path
                self?.handlePath(path)
            }
        }
        monitor.start(queue: monitorQueue)
        self.monitor = monitor
    }

    private func handlePath(_ path: NWPath) {
        guard configuration.isEnabled else {
            setStatus(.off)
            return
        }

        guard !configuration.hotspotSSID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            cancelPendingWork()
            setStatus(.waitingForSSID)
            return
        }

        guard configuration.shouldMonitor else {
            cancelPendingWork()
            setStatus(.ready)
            return
        }

        if path.status == .satisfied {
            cancelPendingWork()
            setStatus(.monitoring)
            return
        }

        scheduleConnectionAttempt()
    }

    private func scheduleConnectionAttempt() {
        switch status {
        case .waitingToRetry, .connecting:
            return
        case .off, .waitingForSSID, .ready, .monitoring, .connected, .failed, .unavailable:
            break
        }

        let ssid = configuration.hotspotSSID.trimmingCharacters(in: .whitespacesAndNewlines)
        let delay = max(5, Int(configuration.retryDelay.rounded()))
        setStatus(.waitingToRetry(delay))
        onEvent?(NetworkRecoveryEvent(detail: "Network unavailable; will try hotspot \"\(ssid)\" in \(delay)s", succeeded: true))

        retryTask?.cancel()
        retryTask = Task { [weak self] in
            do {
                try await Task.sleep(nanoseconds: UInt64(delay) * 1_000_000_000)
            } catch {
                return
            }

            self?.connectToHotspotIfNeeded(ssid: ssid)
        }
    }

    private func connectToHotspotIfNeeded(ssid: String) {
        guard configuration.isEnabled, configuration.shouldMonitor else {
            return
        }

        guard lastPath?.status != .satisfied else {
            setStatus(.monitoring)
            return
        }

        setStatus(.connecting)
        onEvent?(NetworkRecoveryEvent(detail: "Connecting to hotspot \"\(ssid)\"", succeeded: true))

        connectionTask?.cancel()
        connectionTask = Task { [weak self] in
            let result = await NetworkRecoveryConnector.connect(toSSID: ssid)
            self?.handleConnectionResult(result, ssid: ssid)
        }
    }

    private func handleConnectionResult(_ result: NetworkRecoveryAttemptResult, ssid: String) {
        switch result {
        case .success:
            setStatus(.connected(ssid))
            onEvent?(NetworkRecoveryEvent(detail: "Connected to hotspot \"\(ssid)\"", succeeded: true))
        case .wifiDeviceUnavailable:
            setStatus(.unavailable("Wi-Fi device not found"))
            onEvent?(NetworkRecoveryEvent(detail: "Hotspot connection failed: Wi-Fi device not found", succeeded: false))
        case .failed(let message):
            setStatus(.failed(message))
            onEvent?(NetworkRecoveryEvent(detail: "Hotspot connection failed: \(message)", succeeded: false))
            if lastPath?.status != .satisfied {
                scheduleConnectionAttempt()
            }
        }
    }

    private func cancelPendingWork() {
        retryTask?.cancel()
        retryTask = nil
        connectionTask?.cancel()
        connectionTask = nil
    }

    private func setStatus(_ newStatus: NetworkRecoveryStatus) {
        guard status != newStatus else {
            return
        }

        status = newStatus
        onStatusChange?(newStatus)
    }
}

enum NetworkRecoveryAttemptResult: Equatable {
    case success
    case wifiDeviceUnavailable
    case failed(String)
}

enum NetworkRecoveryCandidateResult: Equatable {
    case success([String])
    case failed(String)
}

enum NetworkRecoveryConnector {
    static func wirelessNetworkCandidates() async -> NetworkRecoveryCandidateResult {
        await Task.detached(priority: .utility) {
            switch wifiDevice() {
            case .success(let device):
                let currentNetworkResult = runProcess(
                    executablePath: "/usr/sbin/networksetup",
                    arguments: ["-getairportnetwork", device]
                )
                let preferredNetworksResult = runProcess(
                    executablePath: "/usr/sbin/networksetup",
                    arguments: ["-listpreferredwirelessnetworks", device]
                )

                guard preferredNetworksResult.exitCode == 0 else {
                    return .failed(commandFailureMessage(preferredNetworksResult))
                }

                let currentNetwork = currentNetworkResult.exitCode == 0
                    ? currentNetworkName(from: currentNetworkResult.stdout)
                    : nil
                let candidates = uniqueNetworkNames(
                    [currentNetwork].compactMap { $0 }
                    + preferredNetworkNames(from: preferredNetworksResult.stdout)
                )

                return .success(candidates)
            case .failure(let message):
                return .failed(message)
            }
        }.value
    }

    static func connect(toSSID ssid: String) async -> NetworkRecoveryAttemptResult {
        await Task.detached(priority: .utility) {
            guard case .success(let device) = wifiDevice() else {
                return .wifiDeviceUnavailable
            }

            let result = runProcess(
                executablePath: "/usr/sbin/networksetup",
                arguments: ["-setairportnetwork", device, ssid]
            )

            if result.exitCode == 0 {
                return .success
            }

            return .failed(commandFailureMessage(result))
        }.value
    }

    static func wifiDeviceName(from output: String) -> String? {
        var isWiFiPort = false

        for rawLine in output.split(separator: "\n", omittingEmptySubsequences: false) {
            let line = rawLine.trimmingCharacters(in: .whitespaces)

            if line.hasPrefix("Hardware Port:") {
                isWiFiPort = line.contains("Wi-Fi") || line.contains("AirPort")
                continue
            }

            if isWiFiPort, line.hasPrefix("Device:") {
                return line
                    .replacingOccurrences(of: "Device:", with: "")
                    .trimmingCharacters(in: .whitespaces)
            }
        }

        return nil
    }

    static func preferredNetworkNames(from output: String) -> [String] {
        let names = output
            .split(separator: "\n", omittingEmptySubsequences: false)
            .dropFirst()
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        return uniqueNetworkNames(names)
    }

    static func currentNetworkName(from output: String) -> String? {
        let trimmed = output.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return nil
        }

        if trimmed.localizedCaseInsensitiveContains("not associated") {
            return nil
        }

        guard let separatorIndex = trimmed.firstIndex(of: ":") else {
            return nil
        }

        let name = trimmed[trimmed.index(after: separatorIndex)...]
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return name.isEmpty ? nil : name
    }

    static func uniqueNetworkNames(_ names: [String]) -> [String] {
        var seen = Set<String>()
        var uniqueNames: [String] = []

        for name in names {
            let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedName.isEmpty, seen.insert(trimmedName).inserted else {
                continue
            }
            uniqueNames.append(trimmedName)
        }

        return uniqueNames
    }

    private static func wifiDevice() -> WiFiDeviceLookupResult {
        let result = runProcess(executablePath: "/usr/sbin/networksetup", arguments: ["-listallhardwareports"])
        guard result.exitCode == 0 else {
            return .failure(commandFailureMessage(result))
        }

        guard let device = wifiDeviceName(from: result.stdout) else {
            return .failure("Wi-Fi device not found")
        }

        return .success(device)
    }

    private static func commandFailureMessage(_ result: ProcessResult) -> String {
        let message = result.stderr.isEmpty ? result.stdout : result.stderr
        let trimmedMessage = message.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedMessage.isEmpty ? "networksetup failed with status \(result.exitCode)" : trimmedMessage
    }

    private static func runProcess(executablePath: String, arguments: [String]) -> ProcessResult {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executablePath)
        process.arguments = arguments

        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        do {
            try process.run()
            process.waitUntilExit()

            return ProcessResult(
                exitCode: process.terminationStatus,
                stdout: String(data: outputPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? "",
                stderr: String(data: errorPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
            )
        } catch {
            return ProcessResult(exitCode: -1, stdout: "", stderr: error.localizedDescription)
        }
    }
}

private enum WiFiDeviceLookupResult {
    case success(String)
    case failure(String)
}

private struct ProcessResult {
    let exitCode: Int32
    let stdout: String
    let stderr: String
}

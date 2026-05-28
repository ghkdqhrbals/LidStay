import CoreWLAN
import Foundation
import Network

struct NetworkRecoveryConfiguration: Equatable {
    var isEnabled: Bool
    var hotspotSSID: String
    var hotspotPassword: String
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
        hotspotPassword: "",
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
        let hotspotPassword = configuration.hotspotPassword
        connectionTask = Task { [weak self] in
            let result = await NetworkRecoveryConnector.connect(
                toSSID: ssid,
                password: hotspotPassword
            )
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
    case success(NetworkRecoveryCandidateList)
    case failed(String)
}

struct NetworkRecoveryCandidateList: Equatable {
    let nearby: [String]
    let saved: [String]

    var all: [String] {
        NetworkRecoveryConnector.uniqueNetworkNames(nearby + saved)
    }
}

enum NetworkRecoveryConnector {
    static func wirelessNetworkCandidates() async -> NetworkRecoveryCandidateResult {
        await Task.detached(priority: .utility) {
            switch wifiDevice() {
            case .success(let device):
                let nearbyNetworksResult = nearbyNetworkNames()
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
                let nearbyNetworks = nearbyNetworksResult.names
                let savedNetworks = uniqueNetworkNames(
                    [currentNetwork].compactMap { $0 }
                    + preferredNetworkNames(from: preferredNetworksResult.stdout)
                )

                let candidates = NetworkRecoveryCandidateList(
                    nearby: nearbyNetworks,
                    saved: savedNetworks
                )

                guard !candidates.all.isEmpty else {
                    if let errorMessage = nearbyNetworksResult.errorMessage {
                        return .failed(errorMessage)
                    }
                    return .success(candidates)
                }

                return .success(candidates)
            case .failure(let message):
                return .failed(message)
            }
        }.value
    }

    static func connect(toSSID ssid: String, password: String = "") async -> NetworkRecoveryAttemptResult {
        await Task.detached(priority: .utility) {
            guard case .success(let device) = wifiDevice() else {
                return .wifiDeviceUnavailable
            }

            let targetSSID = ssid.trimmingCharacters(in: .whitespacesAndNewlines)
            let powerResult = ensureWiFiPowerOn(device: device)
            if case .failed(let message) = powerResult {
                return .failed(message)
            }

            let coreWLANResult = await connectUsingCoreWLAN(toSSID: targetSSID, password: password)
            if coreWLANResult == .success {
                return await verifiedConnectionResult(device: device, targetSSID: targetSSID, method: "CoreWLAN")
            }

            let networkSetupResult = runProcess(
                executablePath: "/usr/sbin/networksetup",
                arguments: setAirportNetworkArguments(device: device, ssid: targetSSID, password: password)
            )

            if networkSetupResult.exitCode == 0, !commandReportsJoinFailure(networkSetupResult) {
                return await verifiedConnectionResult(device: device, targetSSID: targetSSID, method: "networksetup")
            }

            let networkSetupMessage = commandFailureMessage(networkSetupResult)
            if case .failed(let coreWLANMessage) = coreWLANResult {
                if coreWLANMessage == coreWLANNetworkNotVisibleMessage(targetSSID: targetSSID),
                   !isNetworkVisibleToSystem(targetSSID) {
                    return .failed("\(hotspotNotBroadcastingMessage(targetSSID: targetSSID)); networksetup failed: \(networkSetupMessage)")
                }
                return .failed("CoreWLAN failed: \(coreWLANMessage); networksetup failed: \(networkSetupMessage)")
            }

            return .failed(networkSetupMessage)
        }.value
    }

    static func setAirportNetworkArguments(device: String, ssid: String, password: String) -> [String] {
        let trimmedPassword = password.trimmingCharacters(in: .whitespacesAndNewlines)
        var arguments = ["-setairportnetwork", device, ssid]
        if !trimmedPassword.isEmpty {
            arguments.append(trimmedPassword)
        }
        return arguments
    }

    static func setAirportPowerArguments(device: String, isOn: Bool) -> [String] {
        ["-setairportpower", device, isOn ? "on" : "off"]
    }

    static func connectionVerificationFailureMessage(
        targetSSID: String,
        currentSSID: String?,
        method: String = "networksetup"
    ) -> String {
        if let currentSSID, !currentSSID.isEmpty {
            return "\(method) finished, but Wi-Fi is still connected to \"\(currentSSID)\" instead of \"\(targetSSID)\""
        }

        return "\(method) finished, but Wi-Fi did not join \"\(targetSSID)\""
    }

    static func hotspotNotBroadcastingMessage(targetSSID: String) -> String {
        "hotspot \"\(targetSSID)\" is not broadcasting as a regular Wi-Fi network. Open Personal Hotspot on iPhone and keep Allow Others to Join enabled."
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

    private static func nearbyNetworkNames() -> NearbyNetworkScanResult {
        var names: [String] = []
        var errorMessage: String?

        if let interface = CWWiFiClient.shared().interface() {
            do {
                let networks = try interface.scanForNetworks(withSSID: nil)
                names += networks
                    .sorted { first, second in
                        if first.rssiValue == second.rssiValue {
                            return (first.ssid ?? "") < (second.ssid ?? "")
                        }
                        return first.rssiValue > second.rssiValue
                    }
                    .compactMap { $0.ssid }
            } catch {
                errorMessage = error.localizedDescription
            }
        } else {
            errorMessage = "Wi-Fi interface not found"
        }

        names += systemProfilerLocalNetworkNames()

        let uniqueNames = uniqueNetworkNames(names)
        return NearbyNetworkScanResult(
            names: uniqueNames,
            errorMessage: uniqueNames.isEmpty ? errorMessage : nil
        )
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

    private static func verifiedConnectionResult(
        device: String,
        targetSSID: String,
        method: String
    ) async -> NetworkRecoveryAttemptResult {
        let trimmedTargetSSID = targetSSID.trimmingCharacters(in: .whitespacesAndNewlines)
        var lastCurrentSSID: String?

        for attempt in 0..<12 {
            lastCurrentSSID = currentWirelessNetworkName(device: device)
            if lastCurrentSSID == trimmedTargetSSID {
                return .success
            }

            if attempt < 11 {
                do {
                    try await Task.sleep(nanoseconds: 750_000_000)
                } catch {
                    return .failed("Wi-Fi connection verification was cancelled")
                }
            }
        }

        if !isNetworkVisibleToSystem(trimmedTargetSSID) {
            return .failed(hotspotNotBroadcastingMessage(targetSSID: trimmedTargetSSID))
        }

        return .failed(connectionVerificationFailureMessage(
            targetSSID: trimmedTargetSSID,
            currentSSID: lastCurrentSSID,
            method: method
        ))
    }

    private static func currentWirelessNetworkName(device: String) -> String? {
        if let ssid = CWWiFiClient.shared().interface()?.ssid(),
           !ssid.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return ssid
        }

        let result = runProcess(
            executablePath: "/usr/sbin/networksetup",
            arguments: ["-getairportnetwork", device]
        )

        guard result.exitCode == 0 else {
            return nil
        }

        return currentNetworkName(from: result.stdout)
    }

    private static func connectUsingCoreWLAN(toSSID ssid: String, password: String) async -> NetworkRecoveryAttemptResult {
        guard let interface = CWWiFiClient.shared().interface() else {
            return .wifiDeviceUnavailable
        }

        let targetSSID = ssid.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !targetSSID.isEmpty else {
            return .failed("Hotspot name is empty")
        }

        do {
            var selectedNetwork: CWNetwork?
            for attempt in 0..<5 {
                selectedNetwork = try visibleNetwork(toSSID: targetSSID, interface: interface)
                if selectedNetwork != nil {
                    break
                }

                if attempt < 4 {
                    try await Task.sleep(nanoseconds: 1_000_000_000)
                }
            }

            guard let selectedNetwork else {
                return .failed(coreWLANNetworkNotVisibleMessage(targetSSID: targetSSID))
            }

            let trimmedPassword = password.trimmingCharacters(in: .whitespacesAndNewlines)
            try interface.associate(to: selectedNetwork, password: trimmedPassword.isEmpty ? nil : trimmedPassword)
            return .success
        } catch {
            return .failed(error.localizedDescription)
        }
    }

    private static func visibleNetwork(toSSID targetSSID: String, interface: CWInterface) throws -> CWNetwork? {
        let targetSSIDData = targetSSID.data(using: .utf8)
        let targetedNetworks = try interface.scanForNetworks(withSSID: targetSSIDData)
        if let targetedNetwork = strongestNetwork(named: targetSSID, in: targetedNetworks) {
            return targetedNetwork
        }

        let allNetworks = try interface.scanForNetworks(withSSID: nil)
        return strongestNetwork(named: targetSSID, in: allNetworks)
    }

    private static func strongestNetwork(named targetSSID: String, in networks: Set<CWNetwork>) -> CWNetwork? {
        networks
            .filter { $0.ssid == targetSSID }
            .sorted { $0.rssiValue > $1.rssiValue }
            .first
    }

    private static func systemProfilerLocalNetworkNames() -> [String] {
        let result = runProcess(
            executablePath: "/usr/sbin/system_profiler",
            arguments: ["SPAirPortDataType"]
        )

        guard result.exitCode == 0 else {
            return []
        }

        return localNetworkNames(fromSystemProfiler: result.stdout)
    }

    private static func isNetworkVisibleToSystem(_ ssid: String) -> Bool {
        nearbyNetworkNames().names.contains(ssid)
    }

    private static func ensureWiFiPowerOn(device: String) -> NetworkRecoveryAttemptResult {
        if CWWiFiClient.shared().interface()?.powerOn() == true {
            return .success
        }

        let result = runProcess(
            executablePath: "/usr/sbin/networksetup",
            arguments: setAirportPowerArguments(device: device, isOn: true)
        )

        guard result.exitCode == 0 else {
            return .failed(commandFailureMessage(result))
        }

        Thread.sleep(forTimeInterval: 2)
        return .success
    }

    private static func commandFailureMessage(_ result: ProcessResult) -> String {
        let message = result.stderr.isEmpty ? result.stdout : result.stderr
        let trimmedMessage = message.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedMessage.isEmpty ? "networksetup failed with status \(result.exitCode)" : trimmedMessage
    }

    private static func coreWLANNetworkNotVisibleMessage(targetSSID: String) -> String {
        "network \"\(targetSSID)\" is not visible to CoreWLAN"
    }

    static func localNetworkNames(fromSystemProfiler output: String) -> [String] {
        var names: [String] = []
        var isInsideNetworkSection = false

        for rawLine in output.split(separator: "\n", omittingEmptySubsequences: false) {
            let line = String(rawLine)
            let leadingSpaces = line.prefix { $0 == " " }.count
            let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)

            if trimmedLine == "Current Network Information:" || trimmedLine == "Other Local Wi-Fi Networks:" {
                isInsideNetworkSection = true
                continue
            }

            guard isInsideNetworkSection else {
                continue
            }

            if !trimmedLine.isEmpty, leadingSpaces <= 8 {
                isInsideNetworkSection = false
                continue
            }

            guard leadingSpaces == 12,
                  trimmedLine.hasSuffix(":"),
                  !trimmedLine.contains("Network Information") else {
                continue
            }

            names.append(String(trimmedLine.dropLast()))
        }

        return uniqueNetworkNames(names)
    }

    private static func commandReportsJoinFailure(_ result: ProcessResult) -> Bool {
        let message = "\(result.stdout)\n\(result.stderr)"
        return message.localizedCaseInsensitiveContains("failed to join network")
            || message.localizedCaseInsensitiveContains("could not be joined")
            || message.localizedCaseInsensitiveContains("error:")
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

private struct NearbyNetworkScanResult {
    let names: [String]
    let errorMessage: String?
}

private struct ProcessResult {
    let exitCode: Int32
    let stdout: String
    let stderr: String
}

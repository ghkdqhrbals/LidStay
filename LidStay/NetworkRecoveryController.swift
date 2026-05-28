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

struct NetworkRecoveryAttemptReport: Equatable {
    let result: NetworkRecoveryAttemptResult
    let events: [NetworkRecoveryEvent]
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
    private var lastPathSummary: String?
    private var lastAvailabilityWarning: String?

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
        lastPathSummary = nil
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
        logPathIfNeeded(path)

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

        if isPathCurrentlyUsable(path) {
            cancelPendingWork()
            let wasMonitoring = status == .monitoring
            setStatus(.monitoring)
            if !wasMonitoring {
                onEvent?(NetworkRecoveryEvent(detail: "Network is available; hotspot recovery is standing by", succeeded: true))
            }
            return
        }

        if isAlreadyConnectedToConfiguredHotspot() {
            cancelPendingWork()
            let ssid = configuration.hotspotSSID.trimmingCharacters(in: .whitespacesAndNewlines)
            setStatus(.connected(ssid))
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
        let delay = max(1, Int(configuration.retryDelay.rounded()))
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

        if let lastPath, isPathCurrentlyUsable(lastPath) {
            setStatus(.monitoring)
            onEvent?(NetworkRecoveryEvent(detail: "Skip hotspot connection because network recovered before retry", succeeded: true))
            return
        }

        if isAlreadyConnectedToConfiguredHotspot() {
            setStatus(.connected(ssid))
            onEvent?(NetworkRecoveryEvent(detail: "Already connected to hotspot \"\(ssid)\"; no recovery action needed", succeeded: true))
            return
        }

        setStatus(.connecting)
        onEvent?(NetworkRecoveryEvent(detail: "Connecting to hotspot \"\(ssid)\"", succeeded: true))

        connectionTask?.cancel()
        let hotspotPassword = configuration.hotspotPassword
        connectionTask = Task { [weak self] in
            let report = await NetworkRecoveryConnector.connectWithDiagnostics(
                toSSID: ssid,
                password: hotspotPassword
            )
            self?.handleConnectionReport(report, ssid: ssid)
        }
    }

    private func handleConnectionReport(_ report: NetworkRecoveryAttemptReport, ssid: String) {
        for event in report.events {
            onEvent?(event)
        }
        handleConnectionResult(report.result, ssid: ssid)
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

    private func logPathIfNeeded(_ path: NWPath) {
        let summary = Self.pathSummary(path)
        guard summary != lastPathSummary else {
            return
        }

        lastPathSummary = summary
        onEvent?(NetworkRecoveryEvent(detail: summary, succeeded: path.status == .satisfied))
    }

    private func isPathCurrentlyUsable(_ path: NWPath) -> Bool {
        let requiresWiFiAssociation = Self.requiresWiFiAssociation(path)
        let currentSSID = requiresWiFiAssociation ? NetworkRecoveryConnector.currentAssociatedWiFiSSID() : nil
        let isUsable = NetworkRecoveryConnector.isUsableNetworkPath(
            statusSatisfied: path.status == .satisfied,
            requiresWiFiAssociation: requiresWiFiAssociation,
            currentWiFiSSID: currentSSID
        )

        if isUsable {
            lastAvailabilityWarning = nil
            return true
        }

        if path.status == .satisfied, requiresWiFiAssociation {
            let warning = "Network path is satisfied, but Wi-Fi is not associated; keeping hotspot retry active"
            if lastAvailabilityWarning != warning {
                lastAvailabilityWarning = warning
                onEvent?(NetworkRecoveryEvent(detail: warning, succeeded: false))
            }
        }

        return false
    }

    private static func requiresWiFiAssociation(_ path: NWPath) -> Bool {
        let hasNonWiFiInterface = path.usesInterfaceType(.wiredEthernet)
            || path.usesInterfaceType(.cellular)
            || path.usesInterfaceType(.other)
        return path.usesInterfaceType(.wifi) && !hasNonWiFiInterface
    }

    private func isAlreadyConnectedToConfiguredHotspot() -> Bool {
        NetworkRecoveryConnector.shouldSkipHotspotJoin(
            currentSSID: NetworkRecoveryConnector.currentAssociatedWiFiSSID(),
            targetSSID: configuration.hotspotSSID
        )
    }

    private static func pathSummary(_ path: NWPath) -> String {
        let activeInterfaces = [
            path.usesInterfaceType(.wifi) ? "wifi" : nil,
            path.usesInterfaceType(.wiredEthernet) ? "ethernet" : nil,
            path.usesInterfaceType(.cellular) ? "cellular" : nil,
            path.usesInterfaceType(.loopback) ? "loopback" : nil,
            path.usesInterfaceType(.other) ? "other" : nil,
        ].compactMap { $0 }

        let activeText = activeInterfaces.isEmpty ? "none" : activeInterfaces.joined(separator: ",")
        let availableText = path.availableInterfaces.map(\.name).joined(separator: ",")

        return "Network path status=\(path.status), reason=\(path.unsatisfiedReason), active=\(activeText), available=\(availableText.isEmpty ? "none" : availableText)"
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
        await connectWithDiagnostics(toSSID: ssid, password: password).result
    }

    static func connectWithDiagnostics(toSSID ssid: String, password: String = "") async -> NetworkRecoveryAttemptReport {
        await Task.detached(priority: .utility) {
            var events: [NetworkRecoveryEvent] = []

            func record(_ detail: String, succeeded: Bool = true) {
                events.append(NetworkRecoveryEvent(detail: detail, succeeded: succeeded))
            }

            func finish(_ result: NetworkRecoveryAttemptResult) -> NetworkRecoveryAttemptReport {
                NetworkRecoveryAttemptReport(result: result, events: events)
            }

            let targetSSID = ssid.trimmingCharacters(in: .whitespacesAndNewlines)
            let hasPassword = !password.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            record("Hotspot recovery started: target=\"\(targetSSID)\", password=\(hasPassword ? "set" : "not set")")

            guard case .success(let device) = wifiDevice() else {
                record("Wi-Fi device lookup failed", succeeded: false)
                return finish(.wifiDeviceUnavailable)
            }
            record("Wi-Fi device detected: \(device)")

            let currentSSIDBefore = currentWirelessNetworkName(device: device)
            record("Current Wi-Fi before recovery: \(currentSSIDBefore.map { "\"\($0)\"" } ?? "not associated")")
            if shouldSkipHotspotJoin(currentSSID: currentSSIDBefore, targetSSID: targetSSID) {
                record("Already connected to hotspot \"\(targetSSID)\"; skipping Wi-Fi commands")
                return finish(.success)
            }

            let serviceResult = ensureWiFiServiceEnabled(device: device, record: record)
            if case .failed(let message) = serviceResult {
                return finish(.failed(message))
            }

            let powerResult = ensureWiFiPowerOn(device: device, record: record)
            if case .failed(let message) = powerResult {
                return finish(.failed(message))
            }

            let firstPass = await connectOnePass(
                device: device,
                targetSSID: targetSSID,
                password: password,
                label: "initial",
                record: record
            )
            if firstPass.result == .success {
                return finish(firstPass.result)
            }

            if currentSSIDBefore == nil, firstPass.hotspotWasNotFound {
                let refreshed = refreshWiFiRadio(device: device, record: record)
                if refreshed {
                    let secondPass = await connectOnePass(
                        device: device,
                        targetSSID: targetSSID,
                        password: password,
                        label: "after Wi-Fi refresh",
                        record: record
                    )
                    return finish(secondPass.result)
                }
            }

            return finish(firstPass.result)
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

    static func redactedAirportNetworkCommand(device: String, ssid: String, password: String) -> String {
        var arguments = setAirportNetworkArguments(device: device, ssid: ssid, password: password)
        if !password.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            arguments[arguments.count - 1] = "<redacted>"
        }

        return "/usr/sbin/networksetup " + arguments.map(logQuotedArgument).joined(separator: " ")
    }

    static func commandOutputReportsJoinFailure(_ message: String) -> Bool {
        message.localizedCaseInsensitiveContains("failed to join network")
            || message.localizedCaseInsensitiveContains("could not be joined")
            || message.localizedCaseInsensitiveContains("could not find network")
            || message.localizedCaseInsensitiveContains("network not found")
            || message.localizedCaseInsensitiveContains("not found")
            || message.localizedCaseInsensitiveContains("error:")
    }

    static func isUsableNetworkPath(
        statusSatisfied: Bool,
        requiresWiFiAssociation: Bool,
        currentWiFiSSID: String?
    ) -> Bool {
        guard statusSatisfied else {
            return false
        }

        guard requiresWiFiAssociation else {
            return true
        }

        guard let currentWiFiSSID else {
            return false
        }

        return !currentWiFiSSID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    static func shouldSkipHotspotJoin(currentSSID: String?, targetSSID: String) -> Bool {
        guard let currentSSID else {
            return false
        }

        return currentSSID.trimmingCharacters(in: .whitespacesAndNewlines)
            == targetSSID.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func currentAssociatedWiFiSSID() -> String? {
        if let ssid = CWWiFiClient.shared().interface()?.ssid(),
           !ssid.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return ssid
        }

        guard case .success(let device) = wifiDevice() else {
            return nil
        }

        return currentWirelessNetworkName(device: device)
    }

    static func networkServiceName(forDevice targetDevice: String, from output: String) -> String? {
        var pendingServiceName: String?

        for rawLine in output.split(separator: "\n", omittingEmptySubsequences: false) {
            let line = String(rawLine).trimmingCharacters(in: .whitespacesAndNewlines)

            if line.hasPrefix("("), !line.contains("Hardware Port:") {
                guard let closingParenthesis = line.firstIndex(of: ")") else {
                    pendingServiceName = nil
                    continue
                }

                pendingServiceName = String(line[line.index(after: closingParenthesis)...])
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                    .trimmingDisabledNetworkServiceMarker()
                continue
            }

            guard line.hasPrefix("(Hardware Port:"),
                  line.contains("Device: \(targetDevice)") else {
                continue
            }

            if let pendingServiceName, !pendingServiceName.isEmpty {
                return pendingServiceName
            }
        }

        return nil
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

    private static func wifiNetworkServiceName(device: String) -> String? {
        let result = runProcess(executablePath: "/usr/sbin/networksetup", arguments: ["-listnetworkserviceorder"])
        guard result.exitCode == 0 else {
            return nil
        }

        return networkServiceName(forDevice: device, from: result.stdout)
    }

    private static func verifiedConnectionResult(
        device: String,
        targetSSID: String,
        method: String,
        record: ((String, Bool) -> Void)? = nil
    ) async -> NetworkRecoveryAttemptResult {
        let trimmedTargetSSID = targetSSID.trimmingCharacters(in: .whitespacesAndNewlines)
        var lastCurrentSSID: String?

        record?("Verifying Wi-Fi join after \(method)", true)
        for attempt in 0..<12 {
            lastCurrentSSID = currentWirelessNetworkName(device: device)
            record?("Verification \(attempt + 1)/12: current=\(lastCurrentSSID.map { "\"\($0)\"" } ?? "not associated")", lastCurrentSSID == trimmedTargetSSID)
            if lastCurrentSSID == trimmedTargetSSID {
                record?("Verified Wi-Fi joined \"\(trimmedTargetSSID)\" using \(method)", true)
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
            record?("Verification failed because \"\(trimmedTargetSSID)\" is no longer visible to system scans", false)
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

    private static func connectOnePass(
        device: String,
        targetSSID: String,
        password: String,
        label: String,
        record: @escaping (String, Bool) -> Void
    ) async -> NetworkRecoveryAttemptPassReport {
        record("Hotspot connection pass: \(label)", true)

        let coreWLANResult = await connectUsingCoreWLAN(toSSID: targetSSID, password: password, record: record)
        if coreWLANResult == .success {
            let result = await verifiedConnectionResult(device: device, targetSSID: targetSSID, method: "CoreWLAN", record: record)
            return NetworkRecoveryAttemptPassReport(result: result, hotspotWasNotFound: false)
        }

        record("Fallback command: \(redactedAirportNetworkCommand(device: device, ssid: targetSSID, password: password))", true)
        let networkSetupResult = runProcess(
            executablePath: "/usr/sbin/networksetup",
            arguments: setAirportNetworkArguments(device: device, ssid: targetSSID, password: password)
        )
        let networkSetupJoinFailed = commandReportsJoinFailure(networkSetupResult)
        record(
            "networksetup exit=\(networkSetupResult.exitCode), stdout=\"\(conciseCommandOutput(networkSetupResult.stdout))\", stderr=\"\(conciseCommandOutput(networkSetupResult.stderr))\"",
            networkSetupResult.exitCode == 0 && !networkSetupJoinFailed
        )

        if networkSetupResult.exitCode == 0, !networkSetupJoinFailed {
            let result = await verifiedConnectionResult(device: device, targetSSID: targetSSID, method: "networksetup", record: record)
            return NetworkRecoveryAttemptPassReport(result: result, hotspotWasNotFound: false)
        }

        let networkSetupMessage = commandFailureMessage(networkSetupResult)
        let networkSetupNotFound = commandReportsNetworkNotFound(networkSetupResult)
        if case .failed(let coreWLANMessage) = coreWLANResult {
            let coreWLANNotVisible = coreWLANMessage == coreWLANNetworkNotVisibleMessage(targetSSID: targetSSID)
            if coreWLANNotVisible, !isNetworkVisibleToSystem(targetSSID) {
                return NetworkRecoveryAttemptPassReport(
                    result: .failed("\(hotspotNotBroadcastingMessage(targetSSID: targetSSID)); networksetup failed: \(networkSetupMessage)"),
                    hotspotWasNotFound: true
                )
            }

            return NetworkRecoveryAttemptPassReport(
                result: .failed("CoreWLAN failed: \(coreWLANMessage); networksetup failed: \(networkSetupMessage)"),
                hotspotWasNotFound: coreWLANNotVisible || networkSetupNotFound
            )
        }

        return NetworkRecoveryAttemptPassReport(
            result: .failed(networkSetupMessage),
            hotspotWasNotFound: networkSetupNotFound
        )
    }

    private static func connectUsingCoreWLAN(
        toSSID ssid: String,
        password: String,
        record: ((String, Bool) -> Void)? = nil
    ) async -> NetworkRecoveryAttemptResult {
        guard let interface = CWWiFiClient.shared().interface() else {
            record?("CoreWLAN interface not found", false)
            return .wifiDeviceUnavailable
        }

        let targetSSID = ssid.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !targetSSID.isEmpty else {
            record?("CoreWLAN skipped because hotspot name is empty", false)
            return .failed("Hotspot name is empty")
        }

        do {
            var selectedNetwork: CWNetwork?
            for attempt in 0..<5 {
                let scanResult = try visibleNetwork(toSSID: targetSSID, interface: interface)
                selectedNetwork = scanResult.network
                if selectedNetwork != nil {
                    let channel = selectedNetwork?.wlanChannel?.channelNumber
                    record?(
                        "CoreWLAN scan \(attempt + 1)/5 found \"\(targetSSID)\" rssi=\(selectedNetwork?.rssiValue ?? 0), channel=\(channel.map(String.init) ?? "unknown"), targeted=\(scanResult.targetedCount), all=\(scanResult.allCount)",
                        true
                    )
                    break
                }

                record?(
                    "CoreWLAN scan \(attempt + 1)/5 did not see \"\(targetSSID)\"; targeted=\(scanResult.targetedCount), all=\(scanResult.allCount)",
                    false
                )
                if attempt < 4 {
                    try await Task.sleep(nanoseconds: 1_000_000_000)
                }
            }

            guard let selectedNetwork else {
                return .failed(coreWLANNetworkNotVisibleMessage(targetSSID: targetSSID))
            }

            let trimmedPassword = password.trimmingCharacters(in: .whitespacesAndNewlines)
            record?("CoreWLAN associate requested for \"\(targetSSID)\"", true)
            try interface.associate(to: selectedNetwork, password: trimmedPassword.isEmpty ? nil : trimmedPassword)
            return .success
        } catch {
            record?("CoreWLAN failed: \(error.localizedDescription)", false)
            return .failed(error.localizedDescription)
        }
    }

    private static func visibleNetwork(toSSID targetSSID: String, interface: CWInterface) throws -> VisibleNetworkScanResult {
        let targetSSIDData = targetSSID.data(using: .utf8)
        let targetedNetworks = try interface.scanForNetworks(withSSID: targetSSIDData)
        if let targetedNetwork = strongestNetwork(named: targetSSID, in: targetedNetworks) {
            return VisibleNetworkScanResult(
                network: targetedNetwork,
                targetedCount: targetedNetworks.count,
                allCount: 0
            )
        }

        let allNetworks = try interface.scanForNetworks(withSSID: nil)
        return VisibleNetworkScanResult(
            network: strongestNetwork(named: targetSSID, in: allNetworks),
            targetedCount: targetedNetworks.count,
            allCount: allNetworks.count
        )
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

    private static func ensureWiFiServiceEnabled(
        device: String,
        record: ((String, Bool) -> Void)? = nil
    ) -> NetworkRecoveryAttemptResult {
        guard let serviceName = wifiNetworkServiceName(device: device) else {
            record?("Wi-Fi network service lookup failed for device \(device); continuing with airport power only", false)
            return .success
        }

        record?("Wi-Fi network service detected: \"\(serviceName)\"", true)
        let result = runProcess(
            executablePath: "/usr/sbin/networksetup",
            arguments: ["-setnetworkserviceenabled", serviceName, "on"]
        )
        record?(
            "Wi-Fi network service enable exit=\(result.exitCode), stdout=\"\(conciseCommandOutput(result.stdout))\", stderr=\"\(conciseCommandOutput(result.stderr))\"",
            result.exitCode == 0
        )

        guard result.exitCode == 0 else {
            return .failed(commandFailureMessage(result))
        }

        Thread.sleep(forTimeInterval: 1)
        return .success
    }

    private static func ensureWiFiPowerOn(
        device: String,
        record: ((String, Bool) -> Void)? = nil
    ) -> NetworkRecoveryAttemptResult {
        let powerOn = CWWiFiClient.shared().interface()?.powerOn()
        record?("Wi-Fi power state before recovery: \(powerOn.map { $0 ? "on" : "off" } ?? "unknown")", powerOn != false)
        if powerOn == true {
            return .success
        }

        record?("Command: /usr/sbin/networksetup \(setAirportPowerArguments(device: device, isOn: true).joined(separator: " "))", true)
        let result = runProcess(
            executablePath: "/usr/sbin/networksetup",
            arguments: setAirportPowerArguments(device: device, isOn: true)
        )
        record?(
            "Wi-Fi power command exit=\(result.exitCode), stdout=\"\(conciseCommandOutput(result.stdout))\", stderr=\"\(conciseCommandOutput(result.stderr))\"",
            result.exitCode == 0
        )

        guard result.exitCode == 0 else {
            return .failed(commandFailureMessage(result))
        }

        Thread.sleep(forTimeInterval: 2)
        return .success
    }

    private static func refreshWiFiRadio(
        device: String,
        record: ((String, Bool) -> Void)? = nil
    ) -> Bool {
        record?("Hotspot was not found while Wi-Fi is disconnected; refreshing Wi-Fi radio once", true)

        let powerOffResult = runProcess(
            executablePath: "/usr/sbin/networksetup",
            arguments: setAirportPowerArguments(device: device, isOn: false)
        )
        record?(
            "Wi-Fi power off exit=\(powerOffResult.exitCode), stdout=\"\(conciseCommandOutput(powerOffResult.stdout))\", stderr=\"\(conciseCommandOutput(powerOffResult.stderr))\"",
            powerOffResult.exitCode == 0
        )
        guard powerOffResult.exitCode == 0 else {
            return false
        }

        Thread.sleep(forTimeInterval: 2)

        let powerOnResult = runProcess(
            executablePath: "/usr/sbin/networksetup",
            arguments: setAirportPowerArguments(device: device, isOn: true)
        )
        record?(
            "Wi-Fi power on exit=\(powerOnResult.exitCode), stdout=\"\(conciseCommandOutput(powerOnResult.stdout))\", stderr=\"\(conciseCommandOutput(powerOnResult.stderr))\"",
            powerOnResult.exitCode == 0
        )
        guard powerOnResult.exitCode == 0 else {
            return false
        }

        Thread.sleep(forTimeInterval: 4)
        return true
    }

    private static func conciseCommandOutput(_ output: String) -> String {
        let trimmed = output
            .replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count > 180 else {
            return trimmed
        }

        return String(trimmed.prefix(177)) + "..."
    }

    private static func logQuotedArgument(_ argument: String) -> String {
        guard !argument.isEmpty else {
            return "\"\""
        }

        if argument.rangeOfCharacter(from: .whitespacesAndNewlines) == nil,
           !argument.contains("\"") {
            return argument
        }

        return "\"\(argument.replacingOccurrences(of: "\"", with: "\\\""))\""
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
        return commandOutputReportsJoinFailure(message)
    }

    private static func commandReportsNetworkNotFound(_ result: ProcessResult) -> Bool {
        let message = "\(result.stdout)\n\(result.stderr)"
        return message.localizedCaseInsensitiveContains("could not find network")
            || message.localizedCaseInsensitiveContains("network not found")
            || message.localizedCaseInsensitiveContains("not found")
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

private struct VisibleNetworkScanResult {
    let network: CWNetwork?
    let targetedCount: Int
    let allCount: Int
}

private struct NetworkRecoveryAttemptPassReport {
    let result: NetworkRecoveryAttemptResult
    let hotspotWasNotFound: Bool
}

private struct ProcessResult {
    let exitCode: Int32
    let stdout: String
    let stderr: String
}

private extension String {
    func trimmingDisabledNetworkServiceMarker() -> String {
        hasPrefix("*") ? String(dropFirst()).trimmingCharacters(in: .whitespacesAndNewlines) : self
    }
}

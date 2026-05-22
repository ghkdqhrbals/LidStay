import AppKit
import Foundation

@MainActor
final class AppState: ObservableObject {
    static let durationOptions: [DurationOption] = [
        DurationOption(id: "infinite", minutes: nil),
        DurationOption(id: "30", minutes: 30),
        DurationOption(id: "60", minutes: 60),
        DurationOption(id: "120", minutes: 120),
        DurationOption(id: "custom", minutes: -1),
    ]
    static let lowBatteryLimitOptions = [10, 15, 20, 30, 40]

    @Published var isSleepPreventionEnabled: Bool {
        didSet {
            defaults.set(isSleepPreventionEnabled, forKey: DefaultsKey.isSleepPreventionEnabled)
            if !isSleepPreventionEnabled {
                clearSession()
                refreshAssertion()
            } else {
                startSelectedSession()
            }
        }
    }

    @Published var allowOnBattery: Bool {
        didSet {
            defaults.set(allowOnBattery, forKey: DefaultsKey.allowOnBattery)
            refreshAssertion()
        }
    }

    @Published var language: AppLanguage {
        didSet {
            defaults.set(language.rawValue, forKey: DefaultsKey.language)
        }
    }

    @Published var launchAtLoginEnabled: Bool {
        didSet {
            guard launchAtLoginEnabled != oldValue else {
                return
            }
            defaults.set(launchAtLoginEnabled, forKey: DefaultsKey.launchAtLoginEnabled)
            setLaunchAtLogin(launchAtLoginEnabled)
        }
    }

    @Published var autoPauseOnLowBattery: Bool {
        didSet {
            defaults.set(autoPauseOnLowBattery, forKey: DefaultsKey.autoPauseOnLowBattery)
            refreshAssertion()
        }
    }

    @Published var lowBatteryLimitText: String {
        didSet {
            defaults.set(lowBatteryLimitText, forKey: DefaultsKey.lowBatteryLimitText)
            refreshAssertion()
        }
    }

    @Published private(set) var powerSourceState: PowerSourceState
    @Published private(set) var batteryPercentage: Int?
    @Published private(set) var assertionState: PowerAssertionState = .stopped
    @Published private(set) var sessionEndDate: Date?
    @Published private(set) var now = Date()
    @Published var durationMinutesText: String {
        didSet {
            defaults.set(durationMinutesText, forKey: DefaultsKey.durationMinutesText)
            if selectedDurationID == "custom", isSleepPreventionEnabled {
                if parsedDurationMinutes != nil {
                    startSelectedSession()
                } else {
                    stopSession()
                }
            }
        }
    }
    @Published var selectedDurationID: String {
        didSet {
            defaults.set(selectedDurationID, forKey: DefaultsKey.selectedDurationID)
            if isSleepPreventionEnabled {
                startSelectedSession()
            }
        }
    }

    private let defaults: UserDefaults
    private let assertionController: PowerAssertionController
    private let powerSourceMonitor: PowerSourceMonitor
    private var sessionTimer: Timer?

    init(
        defaults: UserDefaults = .standard,
        assertionController: PowerAssertionController = PowerAssertionController(),
        powerSourceMonitor: PowerSourceMonitor = PowerSourceMonitor()
    ) {
        self.defaults = defaults
        self.assertionController = assertionController
        self.powerSourceMonitor = powerSourceMonitor
        self.isSleepPreventionEnabled = defaults.bool(forKey: DefaultsKey.isSleepPreventionEnabled)
        self.allowOnBattery = defaults.bool(forKey: DefaultsKey.allowOnBattery)
        self.language = AppLanguage(rawValue: defaults.string(forKey: DefaultsKey.language) ?? "") ?? .korean
        self.launchAtLoginEnabled = defaults.bool(forKey: DefaultsKey.launchAtLoginEnabled)
        self.autoPauseOnLowBattery = defaults.object(forKey: DefaultsKey.autoPauseOnLowBattery) as? Bool ?? true
        self.lowBatteryLimitText = defaults.string(forKey: DefaultsKey.lowBatteryLimitText) ?? "20"
        self.durationMinutesText = defaults.string(forKey: DefaultsKey.durationMinutesText) ?? "60"
        self.selectedDurationID = defaults.string(forKey: DefaultsKey.selectedDurationID) ?? "infinite"
        self.powerSourceState = powerSourceMonitor.currentSnapshot.state
        self.batteryPercentage = powerSourceMonitor.currentSnapshot.batteryPercentage

        powerSourceMonitor.onChange = { [weak self] snapshot in
            Task { @MainActor in
                self?.powerSourceState = snapshot.state
                self?.batteryPercentage = snapshot.batteryPercentage
                self?.refreshAssertion()
            }
        }
        powerSourceMonitor.start()
        startSessionTimer()
        if launchAtLoginEnabled {
            setLaunchAtLogin(true)
        }
        refreshAssertion()
    }

    var statusTitle: String {
        switch assertionState {
        case .active:
            return language == .korean ? "켜두는 중" : "Keeping On"
        case .batteryBlocked:
            return language == .korean ? "잠깐 중지" : "Paused"
        case .acPowerOnly:
            return language == .korean ? "잠깐 중지" : "Paused"
        case .stopped:
            return language == .korean ? "꺼짐" : "Off"
        case .failed:
            return language == .korean ? "실패" : "Failed"
        }
    }

    var statusDetail: String {
        switch assertionState {
        case .active:
            return activeReasonText
        case .batteryBlocked:
            if allowOnBattery, autoPauseOnLowBattery, let batteryPercentage, batteryPercentage <= lowBatteryLimit {
                return language == .korean ? "배터리 \(batteryPercentage)%라서 잠깐 중지했습니다." : "Paused because battery is \(batteryPercentage)%."
            }
            return language == .korean ? "배터리 사용 중이라 잠깐 중지했습니다." : "Paused while running on battery."
        case .acPowerOnly:
            return language == .korean ? "전원 연결을 기다리는 중입니다." : "Waiting for power to be connected."
        case .stopped:
            return language == .korean ? "Mac 켜두기가 꺼져 있습니다." : "Keep Mac On is off."
        case .failed(let code):
            return language == .korean ? "Mac 켜두기를 시작하지 못했습니다. IOReturn \(code)." : "Could not start Keep Mac On. IOReturn \(code)."
        }
    }

    var statusSymbolName: String {
        switch assertionState {
        case .active:
            return "checkmark.circle"
        case .batteryBlocked:
            return "battery.25"
        case .acPowerOnly:
            return "powerplug"
        case .stopped:
            return "pause.circle"
        case .failed:
            return "exclamationmark.triangle"
        }
    }

    var statusIndicatorSymbolName: String {
        assertionState == .active ? "circle.fill" : "circle"
    }

    var menuBarSymbolName: String {
        assertionState == .active ? "bolt.circle.fill" : "bolt.circle"
    }

    var menuBarIconName: String {
        if assertionState == .active, selectedDurationID == "infinite" {
            return "MenuBarIconInfinite"
        }

        return assertionState == .active ? "MenuBarIconOn" : "MenuBarIconOff"
    }

    var menuBarIconSize: CGFloat {
        24
    }

    var isMenuBarIconActive: Bool {
        assertionState == .active
    }

    var sessionSummaryText: String {
        if selectedDurationID == "custom", !canStartCustomDuration {
            return language == .korean ? "시간 입력" : "Enter time"
        }

        guard isSleepPreventionEnabled else {
            return language == .korean ? "꺼짐" : "Off"
        }

        switch assertionState {
        case .active:
            return activeReasonText
        case .batteryBlocked:
            return statusDetail
        case .acPowerOnly:
            return statusDetail
        case .stopped:
            return language == .korean ? "꺼짐" : "Off"
        case .failed:
            return language == .korean ? "실패" : "Failed"
        }
    }

    var endTimeText: String {
        guard let sessionEndDate else {
            return language == .korean ? "직접 끌 때까지 유지" : "Runs until turned off"
        }

        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        return language == .korean ? "\(formatter.string(from: sessionEndDate))에 종료" : "Ends at \(formatter.string(from: sessionEndDate))"
    }

    var timeLabel: String { language == .korean ? "시간 선택" : "Choose time" }
    var timeMenuTitle: String {
        language == .korean ? "시간: \(selectedDurationTitle)" : "Time: \(selectedDurationTitle)"
    }
    var selectedDurationTitle: String {
        if selectedDurationID == "custom", let minutes = parsedDurationMinutes {
            return formattedMinutes(minutes)
        }

        guard let option = Self.durationOptions.first(where: { $0.id == selectedDurationID }) else {
            return durationTitle(for: Self.durationOptions[0])
        }

        return durationTitle(for: option)
    }
    var mainTabTitle: String { language == .korean ? "실행" : "Run" }
    var optionsTabTitle: String { language == .korean ? "옵션" : "Options" }
    var awakeToggleTitle: String { language == .korean ? "Mac 켜두기" : "Keep Mac On" }
    var stopAwakeTitle: String { language == .korean ? "Mac 켜두기 중지" : "Stop Keeping Mac On" }
    var minutesPlaceholder: String { language == .korean ? "분" : "Minutes" }
    var minutesUnit: String { language == .korean ? "분" : "min" }
    var customMinutesTitle: String { language == .korean ? "직접 시간 입력..." : "Custom Minutes..." }
    var customMinutesPromptTitle: String { language == .korean ? "켜둘 시간" : "Duration" }
    var customMinutesPromptMessage: String { language == .korean ? "분 단위로 입력하세요." : "Enter minutes." }
    var cancelTitle: String { language == .korean ? "취소" : "Cancel" }
    var applyTitle: String { language == .korean ? "적용" : "Apply" }
    var moreTitle: String { language == .korean ? "더보기" : "More" }
    var lowBatteryMenuTitle: String {
        if autoPauseOnLowBattery {
            return language == .korean ? "배터리 \(lowBatteryLimit)% 이하에서 자동 중지" : "Pause below \(lowBatteryLimit)% battery"
        }

        return language == .korean ? "배터리 자동 중지 안 함" : "Do not pause on low battery"
    }
    var lowBatteryStatusTitle: String {
        if autoPauseOnLowBattery {
            return language == .korean ? "배터리 \(lowBatteryLimit)% 이하가 되면 잠깐 중지" : "Pauses when battery reaches \(lowBatteryLimit)%"
        }

        return language == .korean ? "배터리가 낮아도 자동 중지하지 않음" : "Does not pause on low battery"
    }
    var lowBatteryToggleTitle: String {
        autoPauseOnLowBattery
            ? (language == .korean ? "배터리 자동 중지 끄기" : "Turn off battery pause")
            : (language == .korean ? "배터리 자동 중지 켜기" : "Turn on battery pause")
    }
    var lowBatteryCustomTitle: String { language == .korean ? "직접 퍼센트 입력..." : "Custom Percent..." }
    var lowBatteryPromptTitle: String { language == .korean ? "배터리 자동 중지" : "Battery Pause" }
    var lowBatteryPromptMessage: String { language == .korean ? "몇 퍼센트 이하에서 잠깐 중지할지 입력하세요." : "Enter the battery percentage where LidStay should pause." }
    var percentPlaceholder: String { language == .korean ? "퍼센트" : "Percent" }
    var allowBatteryTitle: String { language == .korean ? "배터리에서도 사용" : "Allow on Battery" }
    var chargingOnlyTitle: String { language == .korean ? "충전 중일 때만 Mac 켜두기" : "Only keep Mac on while charging" }
    var powerModeStatusTitle: String {
        if !allowOnBattery {
            return language == .korean ? "전원 연결 시에만 Mac 켜둠" : "Keeps Mac on only when plugged in"
        }

        return language == .korean ? "배터리 사용 중에도 Mac 켜둠" : "Keeps Mac on even on battery"
    }
    var powerModeActionTitle: String {
        if !allowOnBattery {
            return language == .korean ? "배터리에서도 켜두기" : "Also keep on battery"
        }

        return language == .korean ? "전원 연결 시에만 켜두기" : "Only keep on when plugged in"
    }
    var chargingOnlyDetail: String {
        language == .korean
            ? "켜면 전원 연결 중에만 동작합니다. 배터리만 사용할 때는 자동으로 기다립니다."
            : "When on, LidStay runs only while power is connected and waits on battery."
    }
    var launchAtLoginTitle: String { language == .korean ? "로그인 시 자동 실행" : "Open at Login" }
    var launchAtLoginStatusTitle: String {
        launchAtLoginEnabled
            ? (language == .korean ? "로그인하면 자동으로 열림" : "Opens automatically after login")
            : (language == .korean ? "로그인해도 자동으로 열리지 않음" : "Does not open automatically after login")
    }
    var launchAtLoginActionTitle: String {
        launchAtLoginEnabled
            ? (language == .korean ? "자동 실행 끄기" : "Turn off auto launch")
            : (language == .korean ? "로그인 시 자동 실행하기" : "Open at login")
    }
    var languageTitle: String { language == .korean ? "언어" : "Language" }
    var languageSwitchTitle: String { language == .korean ? "English" : "한국어" }
    var aboutTitle: String { language == .korean ? "정보..." : "About..." }
    var quitTitle: String { language == .korean ? "종료" : "Quit" }

    var lowBatteryLimit: Int {
        let trimmed = lowBatteryLimitText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let value = Int(trimmed) else {
            return 20
        }

        return min(95, max(1, value))
    }

    func durationTitle(for option: DurationOption) -> String {
        switch option.id {
        case "infinite":
            return language == .korean ? "무제한" : "Unlimited"
        case "30":
            return language == .korean ? "30분" : "30 min"
        case "60":
            return language == .korean ? "1시간" : "1 hour"
        case "120":
            return language == .korean ? "2시간" : "2 hours"
        case "custom":
            return language == .korean ? "직접 입력" : "Custom"
        default:
            return option.id
        }
    }

    private func formattedMinutes(_ minutes: Double) -> String {
        if minutes.truncatingRemainder(dividingBy: 60) == 0, minutes >= 60 {
            let hours = Int(minutes / 60)
            return language == .korean ? "\(hours)시간" : "\(hours)h"
        }

        return language == .korean ? "\(Int(minutes))분" : "\(Int(minutes)) min"
    }

    var parsedDurationMinutes: Double? {
        let trimmed = durationMinutesText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let minutes = Double(trimmed), minutes > 0 else {
            return nil
        }

        return minutes
    }

    var canStartCustomDuration: Bool {
        parsedDurationMinutes != nil
    }

    var canToggleSleepPrevention: Bool {
        selectedDurationID != "custom" || canStartCustomDuration
    }

    func shutdown() {
        sessionTimer?.invalidate()
        assertionController.release()
        powerSourceMonitor.stop()
    }

    func startSession(duration: TimeInterval?) {
        if let duration {
            sessionEndDate = Date().addingTimeInterval(duration)
        } else {
            sessionEndDate = nil
        }

        if !isSleepPreventionEnabled {
            isSleepPreventionEnabled = true
        } else {
            refreshAssertion()
        }
    }

    func startCustomMinutesSession() {
        guard let parsedDurationMinutes else {
            return
        }

        startSession(duration: parsedDurationMinutes * 60)
    }

    func stopSession() {
        clearSession()
        isSleepPreventionEnabled = false
        assertionController.release()
        assertionState = .stopped
    }

    func showAbout() {
        AboutWindowController.shared.show(language: language)
    }

    func selectDuration(_ option: DurationOption) {
        if option.id == "custom" {
            showCustomMinutesPrompt()
            return
        }

        selectedDurationID = option.id
        startSelectedSession()
    }

    func showCustomMinutesPrompt() {
        let alert = NSAlert()
        alert.messageText = customMinutesPromptTitle
        alert.informativeText = customMinutesPromptMessage
        alert.alertStyle = .informational
        alert.addButton(withTitle: applyTitle)
        alert.addButton(withTitle: cancelTitle)

        let textField = NSTextField(frame: NSRect(x: 0, y: 0, width: 180, height: 24))
        textField.stringValue = durationMinutesText
        textField.placeholderString = minutesPlaceholder
        alert.accessoryView = textField

        NSApp.activate(ignoringOtherApps: true)
        let response = alert.runModal()
        guard response == .alertFirstButtonReturn else {
            return
        }

        let trimmed = textField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let minutes = Double(trimmed), minutes > 0 else {
            return
        }

        durationMinutesText = String(format: "%.0f", minutes)
        selectedDurationID = "custom"
        startSelectedSession()
    }

    func selectLowBatteryLimit(_ limit: Int) {
        lowBatteryLimitText = String(limit)
        autoPauseOnLowBattery = true
    }

    func showLowBatteryLimitPrompt() {
        let alert = NSAlert()
        alert.messageText = lowBatteryPromptTitle
        alert.informativeText = lowBatteryPromptMessage
        alert.alertStyle = .informational
        alert.addButton(withTitle: applyTitle)
        alert.addButton(withTitle: cancelTitle)

        let textField = NSTextField(frame: NSRect(x: 0, y: 0, width: 180, height: 24))
        textField.stringValue = "\(lowBatteryLimit)"
        textField.placeholderString = percentPlaceholder
        alert.accessoryView = textField

        NSApp.activate(ignoringOtherApps: true)
        let response = alert.runModal()
        guard response == .alertFirstButtonReturn else {
            return
        }

        let trimmed = textField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let percent = Int(trimmed), percent > 0, percent < 100 else {
            return
        }

        lowBatteryLimitText = String(percent)
        autoPauseOnLowBattery = true
    }

    func switchLanguage() {
        language = language == .korean ? .english : .korean
    }

    func refreshLaunchAtLoginStatus() {
        launchAtLoginEnabled = defaults.bool(forKey: DefaultsKey.launchAtLoginEnabled)
    }

    func startSelectedSession() {
        guard let option = Self.durationOptions.first(where: { $0.id == selectedDurationID }) else {
            startSession(duration: nil)
            return
        }

        if option.id == "custom" {
            guard canStartCustomDuration else {
                stopSession()
                return
            }
            startCustomMinutesSession()
            return
        }

        guard let minutes = option.minutes else {
            startSession(duration: nil)
            return
        }

        startSession(duration: minutes * 60)
    }

    private func refreshAssertion() {
        expireSessionIfNeeded()

        guard isSleepPreventionEnabled else {
            assertionController.release()
            assertionState = .stopped
            return
        }

        switch powerSourceState {
        case .acPower:
            assertionState = assertionController.acquire()
        case .battery:
            if allowOnBattery {
                if autoPauseOnLowBattery, let batteryPercentage, batteryPercentage <= lowBatteryLimit {
                    assertionController.release()
                    assertionState = .batteryBlocked
                    return
                }
                assertionState = assertionController.acquire()
            } else {
                assertionController.release()
                assertionState = .batteryBlocked
            }
        case .unknown:
            if allowOnBattery {
                assertionState = assertionController.acquire()
            } else {
                assertionController.release()
                assertionState = .acPowerOnly
            }
        }
    }

    private var activeReasonText: String {
        let timeText = sessionRemainingText ?? (language == .korean ? "무제한" : "Unlimited")
        let powerText: String

        switch powerSourceState {
        case .acPower:
            powerText = language == .korean ? "전원 연결됨" : "plugged in"
        case .battery:
            if let batteryPercentage {
                powerText = language == .korean ? "배터리 \(batteryPercentage)%" : "\(batteryPercentage)% battery"
            } else {
                powerText = language == .korean ? "배터리 사용 중" : "on battery"
            }
        case .unknown:
            powerText = language == .korean ? "전원 상태 확인 중" : "checking power"
        }

        return language == .korean ? "직접 켜둠 · \(powerText) · \(timeText)" : "Manual · \(powerText) · \(timeText)"
    }

    private var sessionRemainingText: String? {
        guard let sessionEndDate else {
            return nil
        }

        let remaining = max(0, Int(sessionEndDate.timeIntervalSince(now)))
        let hours = remaining / 3600
        let minutes = (remaining % 3600) / 60

        if hours > 0 {
            return language == .korean ? "\(hours)시간 \(minutes)분 남음" : "\(hours)h \(minutes)m left"
        }

        return language == .korean ? "\(max(1, minutes))분 남음" : "\(max(1, minutes))m left"
    }

    private func startSessionTimer() {
        sessionTimer?.invalidate()
        sessionTimer = Timer.scheduledTimer(withTimeInterval: 15, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.now = Date()
                self?.refreshAssertion()
            }
        }
    }

    private func expireSessionIfNeeded() {
        guard let sessionEndDate, Date() >= sessionEndDate else {
            return
        }

        clearSession()
        isSleepPreventionEnabled = false
    }

    private func clearSession() {
        sessionEndDate = nil
    }

    private func setLaunchAtLogin(_ enabled: Bool) {
        if enabled {
            do {
                try LoginItemController.install()
            } catch {
                defaults.set(false, forKey: DefaultsKey.launchAtLoginEnabled)
                launchAtLoginEnabled = false
            }
        } else {
            LoginItemController.uninstall()
        }
    }
}

private enum DefaultsKey {
    static let isSleepPreventionEnabled = "isKeepAwakeEnabled"
    static let allowOnBattery = "allowOnBattery"
    static let durationMinutesText = "durationMinutesText"
    static let selectedDurationID = "selectedDurationID"
    static let language = "language"
    static let launchAtLoginEnabled = "launchAtLoginEnabled"
    static let autoPauseOnLowBattery = "autoPauseOnLowBattery"
    static let lowBatteryLimitText = "lowBatteryLimitText"
}

private enum LoginItemController {
    static let label = "com.ghkdqhrbals.LidStay.loginitem"

    static var plistURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/LaunchAgents", isDirectory: true)
            .appendingPathComponent("\(label).plist")
    }

    static func install() throws {
        guard let executablePath = Bundle.main.executableURL?.path else {
            throw NSError(domain: "LidStayLoginItem", code: 1)
        }

        let launchAgentsURL = plistURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: launchAgentsURL, withIntermediateDirectories: true)

        let plist: [String: Any] = [
            "Label": label,
            "ProgramArguments": [executablePath],
            "RunAtLoad": true,
            "LimitLoadToSessionType": "Aqua",
        ]
        let data = try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
        try data.write(to: plistURL, options: .atomic)
        runLaunchctl(arguments: ["bootout", "gui/\(getuid())", plistURL.path])
        runLaunchctl(arguments: ["bootstrap", "gui/\(getuid())", plistURL.path])
    }

    static func uninstall() {
        runLaunchctl(arguments: ["bootout", "gui/\(getuid())", plistURL.path])
        try? FileManager.default.removeItem(at: plistURL)
    }

    private static func runLaunchctl(arguments: [String]) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        process.arguments = arguments
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        try? process.run()
        process.waitUntilExit()
    }
}

struct DurationOption: Identifiable, Equatable {
    let id: String
    let minutes: TimeInterval?
}

enum AppLanguage: String, CaseIterable, Identifiable {
    case korean = "ko"
    case english = "en"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .korean:
            return "한국어"
        case .english:
            return "English"
        }
    }
}

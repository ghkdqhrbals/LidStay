import AppKit
import Foundation

@MainActor
final class AppState: ObservableObject {
    static let lowBatteryCutoff = 20
    static let durationOptions: [DurationOption] = [
        DurationOption(id: "infinite", minutes: nil),
        DurationOption(id: "30", minutes: 30),
        DurationOption(id: "60", minutes: 60),
        DurationOption(id: "120", minutes: 120),
        DurationOption(id: "custom", minutes: -1),
    ]

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
        refreshAssertion()
    }

    var statusTitle: String {
        switch assertionState {
        case .active:
            return language == .korean ? "켜두는 중" : "Keeping On"
        case .batteryBlocked:
            return language == .korean ? "배터리 제한" : "Battery limited"
        case .acPowerOnly:
            return language == .korean ? "전원 필요" : "Power needed"
        case .stopped:
            return language == .korean ? "꺼짐" : "Off"
        case .failed:
            return language == .korean ? "실패" : "Failed"
        }
    }

    var statusDetail: String {
        switch assertionState {
        case .active:
            if let sessionRemainingText {
                return language == .korean ? "Mac을 켜두고 있습니다. \(sessionRemainingText)" : "Your Mac is staying on. \(sessionRemainingText)"
            }
            return language == .korean ? "Mac을 계속 켜둡니다. 디스플레이 잠자기는 그대로 허용됩니다." : "Your Mac stays on. Display sleep is still allowed."
        case .batteryBlocked:
            if allowOnBattery, let batteryPercentage, batteryPercentage <= Self.lowBatteryCutoff {
                return language == .korean ? "배터리가 \(batteryPercentage)%입니다. \(Self.lowBatteryCutoff)% 이하에서는 Mac 켜두기를 멈춥니다." : "Battery is \(batteryPercentage)%. Keep Mac On pauses at \(Self.lowBatteryCutoff)% or lower."
            }
            return language == .korean ? "전원을 연결하거나 배터리 사용을 허용하세요." : "Connect power or allow battery use."
        case .acPowerOnly:
            return language == .korean ? "전원이 연결되면 Mac 켜두기가 시작됩니다." : "Keep Mac On starts when power is connected."
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
            return sessionRemainingText ?? (language == .korean ? "켜두는 중 · 무제한" : "On · Unlimited")
        case .batteryBlocked:
            return language == .korean ? "대기 중 · 배터리 제한" : "Waiting · Battery limited"
        case .acPowerOnly:
            return language == .korean ? "대기 중 · 전원 필요" : "Waiting · Power needed"
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
    var minutesPlaceholder: String { language == .korean ? "분" : "Minutes" }
    var minutesUnit: String { language == .korean ? "분" : "min" }
    var customMinutesTitle: String { language == .korean ? "직접 시간 입력..." : "Custom Minutes..." }
    var customMinutesPromptTitle: String { language == .korean ? "켜둘 시간" : "Duration" }
    var customMinutesPromptMessage: String { language == .korean ? "분 단위로 입력하세요." : "Enter minutes." }
    var cancelTitle: String { language == .korean ? "취소" : "Cancel" }
    var applyTitle: String { language == .korean ? "적용" : "Apply" }
    var moreTitle: String { language == .korean ? "더보기" : "More" }
    var allowBatteryTitle: String { language == .korean ? "배터리에서도 사용" : "Allow on Battery" }
    var chargingOnlyTitle: String { language == .korean ? "충전 중일 때만 Mac 켜두기" : "Only keep Mac on while charging" }
    var chargingOnlyMenuTitle: String {
        let stateText = !allowOnBattery ? onTitle : offTitle
        return "\(chargingOnlyTitle): \(stateText)"
    }
    var chargingOnlyDetail: String {
        language == .korean
            ? "켜면 전원 연결 중에만 동작합니다. 배터리만 사용할 때는 자동으로 기다립니다."
            : "When on, LidStay runs only while power is connected and waits on battery."
    }
    var languageTitle: String { language == .korean ? "언어" : "Language" }
    var languageSwitchTitle: String { language == .korean ? "English" : "한국어" }
    var aboutTitle: String { language == .korean ? "LidStay 정보" : "About LidStay" }
    var quitTitle: String { language == .korean ? "LidStay 종료" : "Quit LidStay" }
    var onTitle: String { language == .korean ? "켜짐" : "On" }
    var offTitle: String { language == .korean ? "꺼짐" : "Off" }

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
        if isSleepPreventionEnabled {
            startSelectedSession()
        }
    }

    func switchLanguage() {
        language = language == .korean ? .english : .korean
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
                if let batteryPercentage, batteryPercentage <= Self.lowBatteryCutoff {
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

    private var sessionRemainingText: String? {
        guard let sessionEndDate else {
            return nil
        }

        let remaining = max(0, Int(sessionEndDate.timeIntervalSince(now)))
        let hours = remaining / 3600
        let minutes = (remaining % 3600) / 60

        if hours > 0 {
            return language == .korean ? "켜두는 중 · \(hours)시간 \(minutes)분 남음" : "On · \(hours)h \(minutes)m left"
        }

        return language == .korean ? "켜두는 중 · \(max(1, minutes))분 남음" : "On · \(max(1, minutes))m left"
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
}

private enum DefaultsKey {
    static let isSleepPreventionEnabled = "isKeepAwakeEnabled"
    static let allowOnBattery = "allowOnBattery"
    static let durationMinutesText = "durationMinutesText"
    static let selectedDurationID = "selectedDurationID"
    static let language = "language"
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

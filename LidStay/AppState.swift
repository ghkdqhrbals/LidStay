import AppKit
import Foundation
import IOKit
import Security
import UserNotifications

@MainActor
final class AppState: ObservableObject {
    static let durationOptions: [DurationOption] = [
        DurationOption(id: "infinite", minutes: nil),
        DurationOption(id: "10s", minutes: 10.0 / 60.0),
        DurationOption(id: "30s", minutes: 30.0 / 60.0),
        DurationOption(id: "15", minutes: 15),
        DurationOption(id: "30", minutes: 30),
        DurationOption(id: "45", minutes: 45),
        DurationOption(id: "60", minutes: 60),
        DurationOption(id: "90", minutes: 90),
        DurationOption(id: "120", minutes: 120),
        DurationOption(id: "240", minutes: 240),
        DurationOption(id: "480", minutes: 480),
        DurationOption(id: "custom", minutes: -1),
    ]
    @Published var isSleepPreventionEnabled: Bool {
        didSet {
            guard isSleepPreventionEnabled != oldValue else {
                return
            }
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

    @Published var startScreenSaverOnClosedLid: Bool {
        didSet {
            defaults.set(startScreenSaverOnClosedLid, forKey: DefaultsKey.startScreenSaverOnClosedLid)
        }
    }

    @Published var networkRecoveryEnabled: Bool {
        didSet {
            defaults.set(networkRecoveryEnabled, forKey: DefaultsKey.networkRecoveryEnabled)
            if networkRecoveryEnabled {
                refreshNetworkRecoverySSIDCandidates()
            }
            refreshNetworkRecovery()
        }
    }

    @Published var networkRecoverySSIDText: String {
        didSet {
            defaults.set(networkRecoverySSIDText, forKey: DefaultsKey.networkRecoverySSIDText)
            networkRecoveryPasswordText = Self.keychainPassword(for: networkRecoverySSIDText)
            refreshNetworkRecovery()
        }
    }

    @Published var networkRecoveryPasswordText: String {
        didSet {
            Self.setKeychainPassword(networkRecoveryPasswordText, for: networkRecoverySSIDText)
            refreshNetworkRecovery()
        }
    }

    @Published var networkRecoveryRetrySecondsText: String {
        didSet {
            defaults.set(networkRecoveryRetrySecondsText, forKey: DefaultsKey.networkRecoveryRetrySecondsText)
            refreshNetworkRecovery()
        }
    }

    @Published var developerModeEnabled: Bool {
        didSet {
            defaults.set(developerModeEnabled, forKey: DefaultsKey.developerModeEnabled)
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
    @Published private(set) var debugEvents: [DebugEvent] = []
    @Published private(set) var networkRecoveryStatus: NetworkRecoveryStatus = .off
    @Published private(set) var networkRecoveryNearbySSIDs: [String] = []
    @Published private(set) var networkRecoverySavedSSIDs: [String] = []
    @Published private(set) var isNetworkRecoverySSIDRefreshInProgress = false
    @Published private(set) var networkRecoverySSIDRefreshError: String?
    @Published private(set) var isNetworkRecoveryTestInProgress = false
    @Published private(set) var networkRecoveryTestMessage: String?
    @Published private var menuBarIconAnimationName: String?
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
    private let networkRecoveryController: NetworkRecoveryController
    private let notificationController = AppNotificationController.shared
    private var sessionTimer: Timer?
    private var iconAnimationTask: Task<Void, Never>?
    private var cliCommandObserver: NSObjectProtocol?
    @Published private(set) var notificationAuthorizationStatus: UNAuthorizationStatus = .notDetermined

    init(
        defaults: UserDefaults = .standard,
        assertionController: PowerAssertionController = PowerAssertionController(),
        powerSourceMonitor: PowerSourceMonitor = PowerSourceMonitor(),
        networkRecoveryController: NetworkRecoveryController? = nil
    ) {
        self.defaults = defaults
        self.assertionController = assertionController
        self.powerSourceMonitor = powerSourceMonitor
        self.networkRecoveryController = networkRecoveryController ?? NetworkRecoveryController()
        self.isSleepPreventionEnabled = defaults.bool(forKey: DefaultsKey.isSleepPreventionEnabled)
        self.allowOnBattery = defaults.bool(forKey: DefaultsKey.allowOnBattery)
        self.language = AppLanguage(rawValue: defaults.string(forKey: DefaultsKey.language) ?? "") ?? .english
        self.launchAtLoginEnabled = defaults.bool(forKey: DefaultsKey.launchAtLoginEnabled)
        self.autoPauseOnLowBattery = defaults.object(forKey: DefaultsKey.autoPauseOnLowBattery) as? Bool ?? true
        self.startScreenSaverOnClosedLid = defaults.object(forKey: DefaultsKey.startScreenSaverOnClosedLid) as? Bool ?? true
        self.networkRecoveryEnabled = defaults.object(forKey: DefaultsKey.networkRecoveryEnabled) as? Bool ?? false
        let savedNetworkRecoverySSID = defaults.string(forKey: DefaultsKey.networkRecoverySSIDText) ?? ""
        self.networkRecoverySSIDText = savedNetworkRecoverySSID
        self.networkRecoveryPasswordText = Self.keychainPassword(for: savedNetworkRecoverySSID)
        self.networkRecoveryRetrySecondsText = defaults.string(forKey: DefaultsKey.networkRecoveryRetrySecondsText) ?? "30"
        self.developerModeEnabled = defaults.object(forKey: DefaultsKey.developerModeEnabled) as? Bool ?? false
        self.lowBatteryLimitText = defaults.string(forKey: DefaultsKey.lowBatteryLimitText) ?? "20"
        self.durationMinutesText = defaults.string(forKey: DefaultsKey.durationMinutesText) ?? "60"
        self.selectedDurationID = defaults.string(forKey: DefaultsKey.selectedDurationID) ?? "infinite"
        self.powerSourceState = powerSourceMonitor.currentSnapshot.state
        self.batteryPercentage = powerSourceMonitor.currentSnapshot.batteryPercentage

        if let result = assertionController.restoreSystemSleepState() {
            appendDebugEvent(
                title: "IOKit",
                detail: "Startup safety reset SetClamshellSleepState input=0: IOReturn \(result)",
                succeeded: result == kIOReturnSuccess
            )
        }

        CLIInstaller.installBundledCLIIfNeeded()
        notificationController.onAuthorizationStatusChange = { [weak self] status in
            Task { @MainActor in
                self?.notificationAuthorizationStatus = status
            }
        }
        notificationController.prepare()

        self.networkRecoveryController.onStatusChange = { [weak self] status in
            self?.networkRecoveryStatus = status
        }
        self.networkRecoveryController.onEvent = { [weak self] event in
            self?.appendDebugEvent(title: "Network", detail: event.detail, succeeded: event.succeeded)
        }

        powerSourceMonitor.onChange = { [weak self] snapshot in
            Task { @MainActor in
                self?.powerSourceState = snapshot.state
                self?.batteryPercentage = snapshot.batteryPercentage
                self?.refreshAssertion(forceClamshellReapply: true)
            }
        }
        powerSourceMonitor.start()
        startSessionTimer()
        if launchAtLoginEnabled {
            setLaunchAtLogin(true)
        }
        refreshAssertion()
        refreshNetworkRecovery()
        startCLICommandObserver()
        writeCLIStatus()
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

    var statusLineTitle: String {
        statusTitle
    }

    var statusDotImageName: String {
        switch assertionState {
        case .active:
            return "StatusDotGreen"
        case .batteryBlocked, .acPowerOnly:
            return "StatusDotOrange"
        case .failed:
            return "StatusDotRed"
        case .stopped:
            return "StatusDotGray"
        }
    }

    var statusDetail: String {
        switch assertionState {
        case .active:
            return activeSessionText
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

    var networkRecoveryRetrySeconds: Int {
        let parsed = Int(networkRecoveryRetrySecondsText) ?? 30
        return min(600, max(5, parsed))
    }

    var networkRecoveryStatusTitle: String {
        switch networkRecoveryStatus {
        case .off:
            return language == .korean ? "꺼짐" : "Off"
        case .waitingForSSID:
            return language == .korean ? "핫스팟 이름 필요" : "Enter hotspot name"
        case .ready:
            return language == .korean ? "켜두는 중에 감시" : "Ready while keeping on"
        case .monitoring:
            return language == .korean ? "네트워크 감시 중" : "Watching network"
        case .waitingToRetry(let seconds):
            return language == .korean ? "\(seconds)초 후 연결 시도" : "Retry in \(seconds)s"
        case .connecting:
            return language == .korean ? "핫스팟 연결 중" : "Connecting"
        case .connected(let ssid):
            return language == .korean ? "\(ssid)에 연결됨" : "Connected to \(ssid)"
        case .failed:
            return language == .korean ? "연결 실패, 재시도 중" : "Failed, retrying"
        case .unavailable:
            return language == .korean ? "Wi-Fi를 찾지 못함" : "Wi-Fi unavailable"
        }
    }

    var networkRecoverySSIDOptions: [String] {
        NetworkRecoveryConnector.uniqueNetworkNames(
            [networkRecoverySSIDText] + networkRecoveryNearbySSIDs + networkRecoverySavedSSIDs
        )
    }

    var networkRecoveryNearbySSIDOptions: [String] {
        NetworkRecoveryConnector.uniqueNetworkNames(networkRecoveryNearbySSIDs)
    }

    var networkRecoverySavedSSIDOptions: [String] {
        let nearby = Set(networkRecoveryNearbySSIDOptions)
        return NetworkRecoveryConnector.uniqueNetworkNames(networkRecoverySavedSSIDs)
            .filter { !nearby.contains($0) }
    }

    var networkRecoverySelectedSSIDFallbackOption: String? {
        let selected = networkRecoverySSIDText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !selected.isEmpty else {
            return nil
        }

        let knownOptions = Set(networkRecoveryNearbySSIDOptions + networkRecoverySavedSSIDOptions)
        return knownOptions.contains(selected) ? nil : selected
    }

    var networkRecoveryPickerStatusTitle: String {
        if isNetworkRecoverySSIDRefreshInProgress {
            return language == .korean ? "목록 확인 중" : "Checking networks"
        }

        if networkRecoverySSIDRefreshError != nil {
            return language == .korean ? "목록 확인 실패" : "Could not load Wi-Fi"
        }

        if networkRecoverySSIDText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            if networkRecoverySSIDOptions.isEmpty {
                return language == .korean ? "근처 Wi-Fi 없음" : "No nearby Wi-Fi"
            }
            return language == .korean ? "핫스팟 선택" : "Choose hotspot"
        }

        if isSelectedNetworkRecoverySSIDUnavailable {
            return language == .korean ? "iPhone 핫스팟 신호 없음" : "Hotspot not visible"
        }

        return networkRecoveryStatusTitle
    }

    var isNetworkRecoveryValidationErrorVisible: Bool {
        guard !isNetworkRecoverySSIDRefreshInProgress else {
            return false
        }

        if networkRecoverySSIDRefreshError != nil {
            return true
        }

        return isSelectedNetworkRecoverySSIDUnavailable
    }

    private var isSelectedNetworkRecoverySSIDUnavailable: Bool {
        let selectedSSID = networkRecoverySSIDText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !selectedSSID.isEmpty else {
            return false
        }

        let knownSSIDs = Set(
            NetworkRecoveryConnector.uniqueNetworkNames(networkRecoveryNearbySSIDs + networkRecoverySavedSSIDs)
        )
        guard knownSSIDs.contains(selectedSSID) else {
            return true
        }

        return false
    }

    var networkRecoveryTestButtonTitle: String {
        language == .korean ? "연결 테스트" : "Test Connect"
    }

    var canTestNetworkRecoveryConnection: Bool {
        !networkRecoverySSIDText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        && !isNetworkRecoveryTestInProgress
    }

    var networkRecoveryTestStatusTitle: String {
        if isNetworkRecoveryTestInProgress {
            return language == .korean ? "테스트 중" : "Testing"
        }

        if let networkRecoveryTestMessage {
            return networkRecoveryTestMessage
        }

        if networkRecoverySSIDText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return language == .korean ? "핫스팟 선택 필요" : "Choose hotspot first"
        }

        return language == .korean ? "즉시 연결 확인" : "Runs immediately"
    }

    var networkRecoveryPasswordStatusTitle: String {
        if networkRecoverySSIDText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return language == .korean ? "핫스팟 선택 필요" : "Choose hotspot first"
        }

        if networkRecoveryPasswordText.isEmpty {
            return language == .korean ? "iPhone 핫스팟은 암호 필요" : "iPhone hotspot may need password"
        }

        return language == .korean ? "Keychain 저장됨" : "Saved in Keychain"
    }

    var statusIndicatorSymbolName: String {
        assertionState == .active ? "circle.fill" : "circle"
    }

    var menuBarSymbolName: String {
        assertionState == .active ? "bolt.circle.fill" : "bolt.circle"
    }

    var menuBarIconName: String {
        if let menuBarIconAnimationName {
            return menuBarIconAnimationName
        }

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
        guard isSleepPreventionEnabled else {
            return ""
        }

        if selectedDurationID == "custom", !canStartCustomDuration {
            return language == .korean ? "시간 입력" : "Enter time"
        }

        switch assertionState {
        case .active:
            return activeSessionText
        case .batteryBlocked:
            return statusDetail
        case .acPowerOnly:
            return statusDetail
        case .stopped:
            return ""
        case .failed:
            return language == .korean ? "실패" : "Failed"
        }
    }

    var menuStatusText: String {
        if assertionState == .active, sessionEndDate == nil {
            return language == .korean ? "계속 켜두는 중" : "Keeping On"
        }

        guard !sessionSummaryText.isEmpty else {
            return statusLineTitle
        }

        return "\(statusLineTitle) \(sessionSummaryText)\(sessionEndTimeSuffix)"
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
        timeLabel
    }
    var selectedDurationTitle: String {
        if selectedDurationID == "custom", let seconds = parsedDurationSeconds {
            return formattedDuration(seconds: seconds)
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
    var minutesPlaceholder: String { language == .korean ? "예: 10s, 5m, 2h" : "Ex: 10s, 5m, 2h" }
    var minutesUnit: String { language == .korean ? "분" : "min" }
    var customMinutesTitle: String { language == .korean ? "직접 시간 입력..." : "Custom Duration..." }
    var customMinutesPromptTitle: String { language == .korean ? "켜둘 시간" : "Duration" }
    var customMinutesPromptMessage: String {
        language == .korean ? "초, 분, 시간 단위로 입력하세요. 예: 10s, 5m, 2h" : "Enter seconds, minutes, or hours. Ex: 10s, 5m, 2h"
    }
    var cancelTitle: String { language == .korean ? "취소" : "Cancel" }
    var applyTitle: String { language == .korean ? "적용" : "Apply" }
    var moreTitle: String { language == .korean ? "더보기" : "More" }
    var lowBatteryMenuTitle: String {
        if autoPauseOnLowBattery {
            return language == .korean ? "배터리 보호: \(lowBatteryLimit)% 이하" : "Battery protection: below \(lowBatteryLimit)%"
        }

        return language == .korean ? "배터리 보호: 사용 안 함" : "Battery protection: off"
    }
    var lowBatteryStatusTitle: String {
        if autoPauseOnLowBattery {
            return language == .korean ? "배터리 보호: \(lowBatteryLimit)% 이하에서 잠깐 중지" : "Battery protection: pauses below \(lowBatteryLimit)%"
        }

        return language == .korean ? "배터리 보호: 사용 안 함" : "Battery protection: off"
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
    var allowBatteryTitle: String { language == .korean ? "배터리 포함" : "Include battery" }
    var chargingOnlyTitle: String { language == .korean ? "전원 연결 시" : "Power adapter" }
    private var batteryPowerModeTitle: String {
        if autoPauseOnLowBattery {
            return language == .korean ? "배터리 \(lowBatteryLimit)% 이상" : "Battery \(lowBatteryLimit)%+"
        }

        return language == .korean ? "배터리 포함" : "Include battery"
    }

    var powerModeStatusTitle: String {
        if !allowOnBattery {
            return language == .korean ? "실행 조건: \(chargingOnlyTitle)" : "Condition: \(chargingOnlyTitle)"
        }

        return language == .korean ? "실행 조건: \(batteryPowerModeTitle)" : "Condition: \(batteryPowerModeTitle)"
    }
    var powerModeActionTitle: String {
        if !allowOnBattery {
            return language == .korean ? "배터리 조건으로 전환" : "Switch to battery condition"
        }

        return language == .korean ? "전원 연결 조건으로 전환" : "Switch to power adapter condition"
    }
    var chargingOnlyDetail: String {
        language == .korean
            ? "켜면 전원 연결 중일 때만 실행됩니다. 배터리만 사용할 때는 자동으로 기다립니다."
            : "When on, LidStay runs only while the power adapter is connected and waits on battery."
    }
    var debugLogEmptyTitle: String {
        language == .korean ? "아직 실행 기록이 없습니다." : "No debug events yet."
    }
    var clearDebugLogTitle: String {
        language == .korean ? "기록 지우기" : "Clear"
    }
    var debugLogFileHint: String {
        language == .korean
            ? "실행 기록은 앱 안과 debug.log에 남습니다."
            : "Events are shown here and written to debug.log."
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
    var optionsTitle: String { language == .korean ? "옵션" : "Options" }
    var checkForUpdatesTitle: String { language == .korean ? "업데이트 확인" : "Check for Updates" }
    var aboutTitle: String { language == .korean ? "정보" : "About" }
    var quitTitle: String { language == .korean ? "종료" : "Quit" }
    var interruptedNotificationTitle: String {
        language == .korean ? "LidStay가 잠깐 중지되었습니다" : "LidStay paused"
    }
    var sessionEndedNotificationTitle: String {
        language == .korean ? "LidStay 시간이 끝났습니다" : "LidStay session ended"
    }
    var sessionEndedNotificationBody: String {
        language == .korean ? "설정한 시간이 지나 Mac 켜두기를 중지했습니다." : "The selected duration ended, so LidStay stopped keeping the Mac on."
    }
    var testNotificationTitle: String {
        language == .korean ? "LidStay 알림 테스트" : "LidStay notification test"
    }
    var testNotificationBody: String {
        language == .korean ? "알림이 정상적으로 표시됩니다." : "Notifications are working."
    }
    var notificationStatusTitle: String {
        switch notificationAuthorizationStatus {
        case .authorized:
            return language == .korean ? "알림 허용됨" : "Notifications allowed"
        case .denied:
            return language == .korean ? "알림 꺼짐" : "Notifications off"
        case .notDetermined:
            return language == .korean ? "아직 확인 안 함" : "Not asked yet"
        case .provisional:
            return language == .korean ? "조용히 허용됨" : "Allowed quietly"
        case .ephemeral:
            return language == .korean ? "임시 허용됨" : "Allowed temporarily"
        @unknown default:
            return language == .korean ? "상태 알 수 없음" : "Unknown"
        }
    }
    var notificationTestButtonTitle: String {
        language == .korean ? "테스트" : "Test"
    }
    var notificationPermissionButtonTitle: String {
        language == .korean ? "알림 설정" : "Notification Settings"
    }
    var isNotificationDenied: Bool {
        notificationAuthorizationStatus == .denied
    }

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
            return language == .korean ? "계속 켜두기" : "Keep On"
        case "10s":
            return language == .korean ? "10초" : "10 sec"
        case "30s":
            return language == .korean ? "30초" : "30 sec"
        case "15":
            return language == .korean ? "15분" : "15 min"
        case "30":
            return language == .korean ? "30분" : "30 min"
        case "45":
            return language == .korean ? "45분" : "45 min"
        case "60":
            return language == .korean ? "1시간" : "1 hour"
        case "90":
            return language == .korean ? "1시간 30분" : "1.5 hours"
        case "120":
            return language == .korean ? "2시간" : "2 hours"
        case "240":
            return language == .korean ? "4시간" : "4 hours"
        case "480":
            return language == .korean ? "8시간" : "8 hours"
        case "custom":
            return language == .korean ? "직접 입력" : "Custom"
        default:
            return option.id
        }
    }

    private func formattedDuration(seconds: TimeInterval) -> String {
        let totalSeconds = max(1, Int(seconds.rounded()))
        if totalSeconds < 60 {
            return language == .korean ? "\(totalSeconds)초" : "\(totalSeconds) sec"
        }

        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let remainingSeconds = totalSeconds % 60

        if hours > 0 {
            if minutes == 0 {
                return language == .korean ? "\(hours)시간" : "\(hours)h"
            }

            return language == .korean ? "\(hours)시간 \(minutes)분" : "\(hours)h \(minutes)m"
        }

        if remainingSeconds == 0 {
            return language == .korean ? "\(minutes)분" : "\(minutes) min"
        }

        return language == .korean ? "\(minutes)분 \(remainingSeconds)초" : "\(minutes)m \(remainingSeconds)s"
    }

    var parsedDurationMinutes: Double? {
        parsedDurationSeconds.map { $0 / 60 }
    }

    var parsedDurationSeconds: TimeInterval? {
        Self.parseDurationSeconds(from: durationMinutesText)
    }

    static func parseDurationSeconds(from text: String) -> TimeInterval? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return nil
        }

        let lowercased = trimmed.lowercased()
        let numberPart: Substring
        let multiplier: Double

        if lowercased.hasSuffix("seconds") {
            numberPart = lowercased.dropLast("seconds".count)
            multiplier = 1
        } else if lowercased.hasSuffix("second") {
            numberPart = lowercased.dropLast("second".count)
            multiplier = 1
        } else if lowercased.hasSuffix("secs") {
            numberPart = lowercased.dropLast("secs".count)
            multiplier = 1
        } else if lowercased.hasSuffix("sec") {
            numberPart = lowercased.dropLast("sec".count)
            multiplier = 1
        } else if lowercased.hasSuffix("s") {
            numberPart = lowercased.dropLast()
            multiplier = 1
        } else if lowercased.hasSuffix("minutes") {
            numberPart = lowercased.dropLast("minutes".count)
            multiplier = 60
        } else if lowercased.hasSuffix("minute") {
            numberPart = lowercased.dropLast("minute".count)
            multiplier = 60
        } else if lowercased.hasSuffix("mins") {
            numberPart = lowercased.dropLast("mins".count)
            multiplier = 60
        } else if lowercased.hasSuffix("min") {
            numberPart = lowercased.dropLast("min".count)
            multiplier = 60
        } else if lowercased.hasSuffix("m") {
            numberPart = lowercased.dropLast()
            multiplier = 60
        } else if lowercased.hasSuffix("hours") {
            numberPart = lowercased.dropLast("hours".count)
            multiplier = 3600
        } else if lowercased.hasSuffix("hour") {
            numberPart = lowercased.dropLast("hour".count)
            multiplier = 3600
        } else if lowercased.hasSuffix("hrs") {
            numberPart = lowercased.dropLast("hrs".count)
            multiplier = 3600
        } else if lowercased.hasSuffix("hr") {
            numberPart = lowercased.dropLast("hr".count)
            multiplier = 3600
        } else if lowercased.hasSuffix("h") {
            numberPart = lowercased.dropLast()
            multiplier = 3600
        } else {
            numberPart = Substring(lowercased)
            multiplier = 60
        }

        let valueText = numberPart.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let value = Double(valueText), value > 0 else {
            return nil
        }

        return value * multiplier
    }

    var canStartCustomDuration: Bool {
        parsedDurationMinutes != nil
    }

    var canToggleSleepPrevention: Bool {
        selectedDurationID != "custom" || canStartCustomDuration
    }

    var startPreventionUnavailableReason: String? {
        if selectedDurationID == "custom", !canStartCustomDuration {
            return language == .korean
                ? "켜둘 시간을 먼저 입력하세요."
                : "Enter a duration first."
        }

        if !allowOnBattery {
            switch powerSourceState {
            case .battery, .unknown:
                return language == .korean
                    ? "전원 어댑터를 연결하면 켜둘 수 있습니다."
                    : "Connect the power adapter to keep running."
            case .acPower:
                break
            }
        }

        if allowOnBattery,
           autoPauseOnLowBattery,
           let batteryPercentage,
           batteryPercentage <= lowBatteryLimit {
            return language == .korean
                ? "배터리 \(batteryPercentage)%라서 잠깐 중지됩니다."
                : "Paused because battery is \(batteryPercentage)%."
        }

        return nil
    }

    var isWaitingForStartCondition: Bool {
        guard isSleepPreventionEnabled else {
            return false
        }

        switch assertionState {
        case .batteryBlocked, .acPowerOnly:
            return startPreventionUnavailableReason != nil
        case .active, .stopped, .failed:
            return false
        }
    }

    func shutdown() {
        sessionTimer?.invalidate()
        updateDisplayBrightnessForClosedLid(for: .stopped)
        if let result = assertionController.setClamshellSleepDisabled(false, force: true) {
            appendDebugEvent(
                title: "IOKit",
                detail: "SetClamshellSleepState input=0 on shutdown: IOReturn \(result)",
                succeeded: result == kIOReturnSuccess
            )
        }
        assertionController.release()
        powerSourceMonitor.stop()
        networkRecoveryController.stop()
        if let cliCommandObserver {
            DistributedNotificationCenter.default().removeObserver(cliCommandObserver)
        }
    }

    func setSleepPreventionEnabled(_ enabled: Bool) {
        guard enabled != isSleepPreventionEnabled else {
            return
        }

        animateMenuBarIcon(opening: enabled, infinite: selectedDurationID == "infinite")
        isSleepPreventionEnabled = enabled
    }

    func settleMenuBarIconAnimation() {
        iconAnimationTask?.cancel()
        iconAnimationTask = nil
        menuBarIconAnimationName = nil
    }

    func startSession(duration: TimeInterval?) {
        if let duration {
            sessionEndDate = Date().addingTimeInterval(duration)
        } else {
            sessionEndDate = nil
        }

        if !isSleepPreventionEnabled {
            animateMenuBarIcon(opening: true, infinite: selectedDurationID == "infinite")
            isSleepPreventionEnabled = true
        } else {
            refreshAssertion()
        }
        writeCLIStatus()
    }

    func startCustomMinutesSession() {
        guard let parsedDurationSeconds else {
            return
        }

        startSession(duration: parsedDurationSeconds)
    }

    func stopSession() {
        if isSleepPreventionEnabled {
            animateMenuBarIcon(opening: false, infinite: selectedDurationID == "infinite")
        }
        clearSession()
        isSleepPreventionEnabled = false
        assertionController.release()
        assertionState = .stopped
        writeCLIStatus()
        refreshNetworkRecovery()
    }

    func showAbout() {
        AboutWindowController.shared.show(language: language)
    }

    func openBugReport() {
        openGitHubIssue(title: "Bug report", labels: "bug", body: """
        ## What happened?

        ## What did you expect?

        ## Steps to reproduce
        1.
        2.
        3.

        ## Mac and LidStay
        - macOS:
        - Mac model:
        - LidStay version:
        """)
    }

    func openFeatureRequest() {
        openGitHubIssue(title: "Feature request", labels: "enhancement", body: """
        ## What would you like LidStay to do?

        ## Why is this useful?

        ## Additional context
        """)
    }

    func openGitHubIssues() {
        guard let url = URL(string: "https://github.com/ghkdqhrbals/LidStay/issues") else {
            return
        }

        NSWorkspace.shared.open(url)
    }

    func showOptions() {
        OptionsWindowController.shared.show(appState: self)
    }

    func confirmAndUninstall() {
        let alert = NSAlert()
        alert.messageText = language == .korean ? "LidStay를 제거할까요?" : "Remove LidStay?"
        alert.informativeText = language == .korean
            ? "앱과 터미널 명령어를 제거합니다. 권한이 필요한 항목이 있으면 macOS가 관리자 권한을 요청합니다."
            : "This removes the app and command line tool. macOS asks for administrator permission only if required."
        alert.alertStyle = .warning
        alert.addButton(withTitle: language == .korean ? "제거" : "Remove")
        alert.addButton(withTitle: language == .korean ? "취소" : "Cancel")

        NSApp.activate(ignoringOtherApps: true)
        guard alert.runModal() == .alertFirstButtonReturn else {
            return
        }

        uninstall()
    }

    private func uninstall() {
        shutdown()

        let script = Self.uninstallScript()
        if Self.runShellScript(script) || Self.runShellScriptWithAdministratorPrivileges(script) {
            showUninstallCompletedAlert()
            NSApplication.shared.terminate(nil)
        } else {
            showUninstallFailedAlert()
        }
    }

    private func showUninstallCompletedAlert() {
        let alert = NSAlert()
        alert.messageText = language == .korean ? "제거 완료" : "Removed"
        alert.informativeText = language == .korean
            ? "그동안 LidStay를 사용해주셔서 감사합니다."
            : "Thank you for using LidStay."
        alert.alertStyle = .informational
        alert.addButton(withTitle: language == .korean ? "종료" : "Quit")
        NSApp.activate(ignoringOtherApps: true)
        alert.runModal()
    }

    private func showUninstallFailedAlert() {
        let alert = NSAlert()
        alert.messageText = language == .korean ? "제거하지 못했습니다" : "Could not remove LidStay"
        alert.informativeText = language == .korean
            ? "앱 또는 터미널 명령어를 삭제할 권한이 없습니다."
            : "LidStay does not have permission to delete the app or command line tool."
        alert.alertStyle = .warning
        alert.addButton(withTitle: language == .korean ? "확인" : "OK")
        NSApp.activate(ignoringOtherApps: true)
        alert.runModal()
    }

    private static func uninstallScript() -> String {
        [
            "/bin/launchctl bootout gui/$(/usr/bin/id -u) \(Self.shellQuoted(LoginItemController.plistURL.path)) >/dev/null 2>&1 || true",
            "/bin/rm -f \(Self.shellQuoted(LoginItemController.plistURL.path))",
            "/bin/rm -f \(Self.shellQuoted(Self.cliStatusURL.path))",
            "/usr/sbin/pkgutil --forget com.ghkdqhrbals.LidStay.pkg >/dev/null 2>&1 || true",
            "/bin/rm -rf /Applications/LidStay.app /usr/local/bin/lidstay",
        ].joined(separator: "\n")
    }

    private static func runShellScript(_ script: String) -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = ["-c", script]
        do {
            try process.run()
            process.waitUntilExit()
            return process.terminationStatus == 0
        } catch {
            return false
        }
    }

    private static func runShellScriptWithAdministratorPrivileges(_ script: String) -> Bool {
        let appleScript = "do shell script \(Self.appleScriptQuoted(script)) with administrator privileges"
        var error: NSDictionary?
        NSAppleScript(source: appleScript)?.executeAndReturnError(&error)
        return error == nil
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
        guard Self.parseDurationSeconds(from: trimmed) != nil else {
            return
        }

        durationMinutesText = trimmed
        selectedDurationID = "custom"
        startSelectedSession()
    }

    func selectLowBatteryLimit(_ limit: Int) {
        lowBatteryLimitText = String(limit)
        autoPauseOnLowBattery = true
    }

    func selectNetworkRecoveryRetrySeconds(_ seconds: Int) {
        networkRecoveryRetrySecondsText = String(min(600, max(5, seconds)))
    }

    func selectNetworkRecoverySSID(_ ssid: String) {
        let trimmedSSID = ssid.trimmingCharacters(in: .whitespacesAndNewlines)
        networkRecoverySSIDText = trimmedSSID
        if !trimmedSSID.isEmpty {
            networkRecoveryEnabled = true
        }
    }

    func refreshNetworkRecoverySSIDCandidatesIfNeeded() {
        guard networkRecoveryNearbySSIDs.isEmpty, networkRecoverySavedSSIDs.isEmpty else {
            return
        }

        refreshNetworkRecoverySSIDCandidates()
    }

    func refreshNetworkRecoverySSIDCandidates() {
        guard !isNetworkRecoverySSIDRefreshInProgress else {
            return
        }

        isNetworkRecoverySSIDRefreshInProgress = true
        Task { [weak self] in
            let result = await NetworkRecoveryConnector.wirelessNetworkCandidates()

            guard let self else {
                return
            }

            switch result {
            case .success(let candidates):
                self.networkRecoveryNearbySSIDs = candidates.nearby
                self.networkRecoverySavedSSIDs = candidates.saved
                self.networkRecoverySSIDRefreshError = nil
                self.appendDebugEvent(
                    title: "Network",
                    detail: "Loaded \(candidates.nearby.count) nearby and \(candidates.saved.count) saved Wi-Fi network candidates",
                    succeeded: true
                )
            case .failed(let message):
                self.networkRecoveryNearbySSIDs = []
                self.networkRecoverySavedSSIDs = []
                self.networkRecoverySSIDRefreshError = message
                self.appendDebugEvent(
                    title: "Network",
                    detail: "Load Wi-Fi networks failed: \(message)",
                    succeeded: false
                )
            }

            self.isNetworkRecoverySSIDRefreshInProgress = false
        }
    }

    func testNetworkRecoveryConnection() {
        let ssid = networkRecoverySSIDText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !ssid.isEmpty else {
            networkRecoveryTestMessage = language == .korean ? "핫스팟 선택 필요" : "Choose hotspot first"
            networkRecoveryStatus = .waitingForSSID
            return
        }

        networkRecoveryEnabled = true
        isNetworkRecoveryTestInProgress = true
        networkRecoveryTestMessage = nil
        networkRecoveryStatus = .connecting
        appendDebugEvent(title: "Network", detail: "Testing hotspot connection to \"\(ssid)\"", succeeded: true)

        Task { [weak self] in
            let report = await NetworkRecoveryConnector.connectWithDiagnostics(
                toSSID: ssid,
                password: self?.networkRecoveryPasswordText ?? ""
            )

            guard let self else {
                return
            }

            for event in report.events {
                self.appendDebugEvent(title: "Network", detail: event.detail, succeeded: event.succeeded)
            }

            self.isNetworkRecoveryTestInProgress = false
            switch report.result {
            case .success:
                self.networkRecoveryStatus = .connected(ssid)
                self.networkRecoveryTestMessage = self.language == .korean ? "연결 성공" : "Connected"
                self.appendDebugEvent(title: "Network", detail: "Hotspot test connected to \"\(ssid)\"", succeeded: true)
            case .wifiDeviceUnavailable:
                self.networkRecoveryStatus = .unavailable("Wi-Fi device not found")
                self.networkRecoveryTestMessage = self.language == .korean ? "Wi-Fi를 찾지 못함" : "Wi-Fi unavailable"
                self.appendDebugEvent(title: "Network", detail: "Hotspot test failed: Wi-Fi device not found", succeeded: false)
            case .failed(let message):
                self.networkRecoveryStatus = .failed(message)
                self.networkRecoveryTestMessage = self.networkRecoveryConnectionFailureTitle(from: message)
                self.appendDebugEvent(title: "Network", detail: "Hotspot test failed: \(message)", succeeded: false)
            }
        }
    }

    private func networkRecoveryConnectionFailureTitle(from message: String) -> String {
        if message.contains("Wi-Fi is still connected") || message.contains("Wi-Fi did not join") {
            return language == .korean ? "실제 연결 안 됨" : "Not connected"
        }

        return language == .korean ? "연결 실패" : "Connection failed"
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

    func sendTestNotification() {
        notificationController.sendNotification(
            title: testNotificationTitle,
            body: testNotificationBody
        )
    }

    func requestNotificationPermission() {
        notificationController.requestAuthorizationOrOpenSettings { didOpenSettings in
            if !didOpenSettings {
                OptionsWindowController.shared.bringForwardIfVisible()
            }
        }
    }

    func openNotificationSettings() {
        notificationController.openSettings()
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

    private func refreshAssertion(forceClamshellReapply: Bool = false) {
        expireSessionIfNeeded()
        let previousState = assertionState

        guard isSleepPreventionEnabled else {
            assertionController.release()
            updateAssertionState(.stopped, previousState: previousState, forceClamshellReapply: forceClamshellReapply)
            writeCLIStatus()
            refreshNetworkRecovery()
            return
        }

        switch powerSourceState {
        case .acPower:
            updateAssertionState(assertionController.acquire(), previousState: previousState, forceClamshellReapply: forceClamshellReapply)
        case .battery:
            if allowOnBattery {
                if autoPauseOnLowBattery, let batteryPercentage, batteryPercentage <= lowBatteryLimit {
                    assertionController.release()
                    updateAssertionState(.batteryBlocked, previousState: previousState, forceClamshellReapply: forceClamshellReapply)
                    writeCLIStatus()
                    refreshNetworkRecovery()
                    return
                }
                updateAssertionState(assertionController.acquire(), previousState: previousState, forceClamshellReapply: forceClamshellReapply)
            } else {
                assertionController.release()
                updateAssertionState(.batteryBlocked, previousState: previousState, forceClamshellReapply: forceClamshellReapply)
            }
        case .unknown:
            if allowOnBattery {
                updateAssertionState(assertionController.acquire(), previousState: previousState, forceClamshellReapply: forceClamshellReapply)
            } else {
                assertionController.release()
                updateAssertionState(.acPowerOnly, previousState: previousState, forceClamshellReapply: forceClamshellReapply)
            }
        }

        writeCLIStatus()
        refreshNetworkRecovery()
    }

    private func refreshNetworkRecovery() {
        networkRecoveryController.update(configuration: NetworkRecoveryConfiguration(
            isEnabled: networkRecoveryEnabled,
            hotspotSSID: networkRecoverySSIDText,
            hotspotPassword: networkRecoveryPasswordText,
            retryDelay: TimeInterval(networkRecoveryRetrySeconds),
            shouldMonitor: assertionState == .active
        ))
    }

    private func updateAssertionState(
        _ newState: PowerAssertionState,
        previousState: PowerAssertionState,
        forceClamshellReapply: Bool = false
    ) {
        assertionState = newState

        if previousState != .active, newState == .active {
            appendDebugEvent(
                title: "IOKit",
                detail: "Create PreventSystemSleep + PreventUserIdleDisplaySleep assertions",
                succeeded: true
            )
        } else if previousState == .active, newState != .active {
            appendDebugEvent(
                title: "IOKit",
                detail: "Release PreventSystemSleep + PreventUserIdleDisplaySleep assertions",
                succeeded: true
            )
        }

        if case .failed(let code) = newState {
            appendDebugEvent(
                title: "IOKit",
                detail: "Create sleep/display assertion failed: IOReturn \(code)",
                succeeded: false
            )
        }

        updateClamshellSleepState(for: newState, force: forceClamshellReapply)
        updateDisplayBrightnessForClosedLid(for: newState)

        guard isSleepPreventionEnabled, previousState == .active, newState != .active else {
            return
        }

        switch newState {
        case .batteryBlocked, .acPowerOnly, .failed:
            notificationController.sendNotification(
                title: interruptedNotificationTitle,
                body: statusDetail
            )
        case .active, .stopped:
            return
        }
    }

    private var activeSessionText: String {
        sessionRemainingText ?? (language == .korean ? "계속 켜두기" : "Keep On")
    }

    private var sessionEndTimeSuffix: String {
        guard let sessionEndDate else {
            return ""
        }

        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        let timeText = formatter.string(from: sessionEndDate)
        return language == .korean ? "(~\(timeText))" : "(until \(timeText))"
    }

    private var sessionRemainingText: String? {
        guard let sessionEndDate else {
            return nil
        }

        let remaining = max(0, Int(sessionEndDate.timeIntervalSince(now)))
        let hours = remaining / 3600
        let minutes = (remaining % 3600) / 60
        let seconds = remaining % 60

        if hours > 0 {
            return language == .korean ? "\(hours)시간 \(minutes)분 남음" : "\(hours)h \(minutes)m left"
        }

        if minutes == 0 {
            return language == .korean ? "\(max(1, seconds))초 남음" : "\(max(1, seconds))s left"
        }

        return language == .korean ? "\(max(1, minutes))분 남음" : "\(max(1, minutes))m left"
    }

    private func startSessionTimer() {
        sessionTimer?.invalidate()
        sessionTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
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

        let shouldNotify = isSleepPreventionEnabled
        clearSession()
        animateMenuBarIcon(opening: false, infinite: selectedDurationID == "infinite")
        isSleepPreventionEnabled = false
        if shouldNotify {
            notificationController.sendNotification(
                title: sessionEndedNotificationTitle,
                body: sessionEndedNotificationBody
            )
        }
    }

    private func clearSession() {
        sessionEndDate = nil
    }

    private func animateMenuBarIcon(opening: Bool, infinite: Bool) {
        iconAnimationTask?.cancel()

        let frameIndexes = opening ? Array(0...4) : Array((0...4).reversed())
        let prefix = infinite ? "MenuBarIconInfiniteFrame" : "MenuBarIconFrame"
        let frames = frameIndexes.map { "\(prefix)\($0)" }
        menuBarIconAnimationName = frames.first

        iconAnimationTask = Task { @MainActor [weak self] in
            for frame in frames.dropFirst() {
                guard !Task.isCancelled else {
                    return
                }
                try? await Task.sleep(nanoseconds: 42_000_000)
                self?.menuBarIconAnimationName = frame
            }
            try? await Task.sleep(nanoseconds: 42_000_000)
            self?.menuBarIconAnimationName = nil
        }
    }

    private func startCLICommandObserver() {
        cliCommandObserver = DistributedNotificationCenter.default().addObserver(
            forName: .lidStayCLICommand,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            Task { @MainActor in
                self?.handleCLICommand(notification)
            }
        }
    }

    private func handleCLICommand(_ notification: Notification) {
        guard let action = notification.userInfo?["action"] as? String else {
            return
        }

        switch action {
        case "on":
            if let rawDuration = notification.userInfo?["durationSeconds"] as? String,
               let duration = TimeInterval(rawDuration),
               duration > 0 {
                selectDurationForCLI(seconds: duration)
                startSession(duration: duration)
            } else {
                selectedDurationID = "infinite"
                startSession(duration: nil)
            }
        case "off":
            stopSession()
        case "status":
            writeCLIStatus()
        case "notify-test":
            sendTestNotification()
        default:
            return
        }
    }

    private func selectDurationForCLI(seconds: TimeInterval) {
        let roundedSeconds = Int(seconds.rounded())
        if let option = Self.durationOptions.first(where: { option in
            guard let minutes = option.minutes, minutes > 0 else {
                return false
            }

            return Int((minutes * 60).rounded()) == roundedSeconds
        }) {
            selectedDurationID = option.id
        } else {
            if roundedSeconds < 60 || roundedSeconds % 60 != 0 {
                durationMinutesText = "\(max(1, roundedSeconds))s"
            } else {
                durationMinutesText = "\(roundedSeconds / 60)"
            }
            selectedDurationID = "custom"
        }
    }

    private func writeCLIStatus() {
        let isoFormatter = ISO8601DateFormatter()
        let statusURL = Self.cliStatusURL
        let status: [String: Any] = [
            "enabled": isSleepPreventionEnabled,
            "state": assertionState.cliValue,
            "title": statusTitle,
            "detail": statusDetail,
            "duration": selectedDurationTitle,
            "sessionEndDate": sessionEndDate.map { isoFormatter.string(from: $0) } as Any,
            "updatedAt": isoFormatter.string(from: Date()),
        ]

        do {
            try FileManager.default.createDirectory(
                at: statusURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            let data = try JSONSerialization.data(withJSONObject: status, options: [.prettyPrinted, .sortedKeys])
            try data.write(to: statusURL, options: .atomic)
        } catch {
            return
        }
    }

    private static var cliStatusURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/LidStay/status.json")
    }

    func clearDebugEvents() {
        debugEvents.removeAll()
        try? FileManager.default.removeItem(at: Self.debugLogURL)
    }

    private func appendDebugEvent(title: String, detail: String, succeeded: Bool) {
        let event = DebugEvent(date: Date(), title: title, detail: detail, succeeded: succeeded)
        debugEvents.insert(event, at: 0)
        if debugEvents.count > 80 {
            debugEvents.removeLast(debugEvents.count - 80)
        }
        appendDebugEventToFile(event)
    }

    private func appendDebugEventToFile(_ event: DebugEvent) {
        let isoFormatter = ISO8601DateFormatter()
        let line = "\(isoFormatter.string(from: event.date)) [\(event.succeeded ? "ok" : "failed")] \(event.title) - \(event.detail)\n"
        let logURL = Self.debugLogURL

        do {
            try FileManager.default.createDirectory(
                at: logURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )

            if FileManager.default.fileExists(atPath: logURL.path),
               let handle = try? FileHandle(forWritingTo: logURL) {
                try handle.seekToEnd()
                if let data = line.data(using: .utf8) {
                    try handle.write(contentsOf: data)
                }
                try handle.close()
            } else {
                try line.write(to: logURL, atomically: true, encoding: .utf8)
            }
        } catch {
            return
        }
    }

    private static var debugLogURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/LidStay/debug.log")
    }

    private func updateClamshellSleepState(for state: PowerAssertionState, force: Bool = false) {
        let shouldDisableClamshellSleep = state == .active
        guard let result = assertionController.setClamshellSleepDisabled(shouldDisableClamshellSleep, force: force) else {
            return
        }

        appendDebugEvent(
            title: "IOKit",
            detail: "SetClamshellSleepState input=\(shouldDisableClamshellSleep ? 1 : 0): IOReturn \(result)",
            succeeded: result == kIOReturnSuccess
        )
    }

    private func updateDisplayBrightnessForClosedLid(for state: PowerAssertionState) {
        guard let event = assertionController.updateDisplayBrightnessForClosedLid(active: state == .active) else {
            return
        }

        appendDebugEvent(
            title: "Display",
            detail: event.detail,
            succeeded: event.succeeded
        )

        if event.kind == .closedLidBrightnessDimmed, event.succeeded, startScreenSaverOnClosedLid {
            startScreenSaverForClosedLid()
        }
    }

    private func startScreenSaverForClosedLid() {
        let started = ScreenSaverController.start()
        appendDebugEvent(
            title: "Screen Saver",
            detail: started ? "Start ScreenSaverEngine on closed lid" : "Start ScreenSaverEngine failed",
            succeeded: started
        )
    }

    private static func shellQuoted(_ value: String) -> String {
        "'\(value.replacingOccurrences(of: "'", with: "'\\''"))'"
    }

    private static func appleScriptQuoted(_ value: String) -> String {
        "\"\(value.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\""))\""
    }

    private static func keychainPassword(for ssid: String) -> String {
        let account = ssid.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !account.isEmpty else {
            return ""
        }

        var item: CFTypeRef?
        let status = SecItemCopyMatching([
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainNetworkRecoveryPasswordService,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ] as CFDictionary, &item)

        guard status == errSecSuccess,
              let data = item as? Data,
              let password = String(data: data, encoding: .utf8) else {
            return ""
        }

        return password
    }

    private static func setKeychainPassword(_ password: String, for ssid: String) {
        let account = ssid.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !account.isEmpty else {
            return
        }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainNetworkRecoveryPasswordService,
            kSecAttrAccount as String: account
        ]

        guard !password.isEmpty else {
            SecItemDelete(query as CFDictionary)
            return
        }

        let data = Data(password.utf8)
        let updateStatus = SecItemUpdate(query as CFDictionary, [
            kSecValueData as String: data
        ] as CFDictionary)

        if updateStatus == errSecItemNotFound {
            var attributes = query
            attributes[kSecValueData as String] = data
            SecItemAdd(attributes as CFDictionary, nil)
        }
    }

    private func openGitHubIssue(title: String, labels: String, body: String) {
        var components = URLComponents(string: "https://github.com/ghkdqhrbals/LidStay/issues/new")
        components?.queryItems = [
            URLQueryItem(name: "title", value: title),
            URLQueryItem(name: "labels", value: labels),
            URLQueryItem(name: "body", value: body)
        ]

        guard let url = components?.url else {
            openGitHubIssues()
            return
        }

        NSWorkspace.shared.open(url)
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

private final class AppNotificationController: NSObject, UNUserNotificationCenterDelegate {
    static let shared = AppNotificationController()

    private let center = UNUserNotificationCenter.current()
    private var hasPrepared = false
    var onAuthorizationStatusChange: ((UNAuthorizationStatus) -> Void)?

    private override init() {
        super.init()
    }

    func prepare() {
        guard !hasPrepared else {
            return
        }

        hasPrepared = true
        center.delegate = self
        refreshAuthorizationStatus()
    }

    func sendNotification(title: String, body: String) {
        center.getNotificationSettings { [weak self] settings in
            guard let self else {
                return
            }

            switch settings.authorizationStatus {
            case .authorized, .provisional, .ephemeral:
                self.addNativeNotification(title: title, body: body)
                self.refreshAuthorizationStatus()
            case .notDetermined:
                self.center.requestAuthorization(options: [.alert, .sound]) { granted, error in
                    self.refreshAuthorizationStatus()
                    if granted, error == nil {
                        self.addNativeNotification(title: title, body: body)
                    }
                }
            case .denied:
                self.refreshAuthorizationStatus()
            @unknown default:
                self.refreshAuthorizationStatus()
            }
        }
    }

    func requestAuthorizationOrOpenSettings(completion: ((Bool) -> Void)? = nil) {
        center.getNotificationSettings { [weak self] settings in
            guard let self else {
                return
            }

            guard settings.authorizationStatus == .notDetermined else {
                self.refreshAuthorizationStatus()
                DispatchQueue.main.async {
                    self.openSettings()
                    completion?(true)
                }
                return
            }

            self.center.requestAuthorization(options: [.alert, .sound]) { [weak self] _, _ in
                self?.refreshAuthorizationStatus()
                DispatchQueue.main.async {
                    completion?(false)
                }
            }
        }
    }

    func openSettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.Notifications-Settings.extension") else {
            return
        }

        NSWorkspace.shared.open(url)
    }

    private func refreshAuthorizationStatus() {
        center.getNotificationSettings { [weak self] settings in
            self?.onAuthorizationStatusChange?(settings.authorizationStatus)
        }
    }

    private func addNativeNotification(title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        content.interruptionLevel = .active

        let request = UNNotificationRequest(
            identifier: "lidstay.notification.\(UUID().uuidString)",
            content: content,
            trigger: nil
        )
        center.add(request) { [weak self] error in
            if error != nil {
                self?.refreshAuthorizationStatus()
            }
        }
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .list, .sound]
    }
}

private let keychainNetworkRecoveryPasswordService = "com.ghkdqhrbals.LidStay.networkRecoveryPassword"

private enum DefaultsKey {
    static let isSleepPreventionEnabled = "isKeepAwakeEnabled"
    static let allowOnBattery = "allowOnBattery"
    static let durationMinutesText = "durationMinutesText"
    static let selectedDurationID = "selectedDurationID"
    static let language = "language"
    static let launchAtLoginEnabled = "launchAtLoginEnabled"
    static let autoPauseOnLowBattery = "autoPauseOnLowBattery"
    static let lowBatteryLimitText = "lowBatteryLimitText"
    static let startScreenSaverOnClosedLid = "startScreenSaverOnClosedLid"
    static let networkRecoveryEnabled = "networkRecoveryEnabled"
    static let networkRecoverySSIDText = "networkRecoverySSIDText"
    static let networkRecoveryRetrySecondsText = "networkRecoveryRetrySecondsText"
    static let developerModeEnabled = "developerModeEnabled"
}

private enum ScreenSaverController {
    static func start() -> Bool {
        let executableURL = URL(fileURLWithPath: "/System/Library/CoreServices/ScreenSaverEngine.app/Contents/MacOS/ScreenSaverEngine")
        guard FileManager.default.fileExists(atPath: executableURL.path) else {
            return false
        }

        let process = Process()
        process.executableURL = executableURL

        do {
            try process.run()
            return true
        } catch {
            return false
        }
    }
}

struct DebugEvent: Identifiable, Equatable {
    let id = UUID()
    let date: Date
    let title: String
    let detail: String
    let succeeded: Bool

    var timeText: String {
        Self.timeFormatter.string(from: date)
    }

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeStyle = .medium
        formatter.dateStyle = .none
        return formatter
    }()
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

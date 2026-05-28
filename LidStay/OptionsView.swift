import SwiftUI

struct OptionsView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var updateController: UpdateController
    @State private var helpTopic: HelpTopic?

    private var isKorean: Bool {
        appState.language == .korean
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 4) {
                Text(isKorean ? "옵션" : "Options")
                    .font(.title3.weight(.semibold))
                Text(isKorean ? "Mac 켜두기 조건과 앱 동작만 설정합니다." : "Set only the keep-on condition and app behavior.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            Divider()

            VStack(alignment: .leading, spacing: 14) {
                optionRow(title: isKorean ? "실행 조건" : "Condition", topic: .powerCondition) {
                    Picker("", selection: powerConditionBinding) {
                        Text(isKorean ? "전원 연결 시" : "Power adapter")
                            .tag(PowerCondition.powerAdapter)
                        Text(appState.autoPauseOnLowBattery ? batteryThresholdTitle : batteryUnlimitedTitle)
                            .tag(PowerCondition.battery)
                    }
                    .labelsHidden()
                    .pickerStyle(.segmented)
                    .frame(width: 260)
                }

                optionRow(title: isKorean ? "배터리 보호" : "Battery", topic: .batteryProtection) {
                    HStack(spacing: 10) {
                        Toggle("", isOn: $appState.autoPauseOnLowBattery)
                            .labelsHidden()
                        Text(batteryProtectionSummary)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    .disabled(!isBatteryConditionSelected)
                }

                optionRow(title: isKorean ? "배터리 기준" : "Limit") {
                    HStack(spacing: 10) {
                        Text("1%")
                            .foregroundStyle(.secondary)
                            .font(.caption)
                            .frame(width: 26, alignment: .trailing)
                        Slider(value: lowBatteryLimitBinding, in: 1...95, step: 1)
                            .frame(width: 220)
                        Text("95%")
                            .foregroundStyle(.secondary)
                            .font(.caption)
                            .frame(width: 32, alignment: .leading)
                        Text("\(appState.lowBatteryLimit)%")
                            .font(.body.monospacedDigit())
                            .frame(width: 42, alignment: .trailing)
                    }
                    .disabled(!isBatteryConditionSelected || !appState.autoPauseOnLowBattery)
                }

                optionRow(title: isKorean ? "화면 보호기" : "Screen Saver") {
                    HStack(spacing: 10) {
                        Toggle("", isOn: $appState.startScreenSaverOnClosedLid)
                            .labelsHidden()
                        Text(isKorean ? "덮개 닫힘 시 실행" : "Starts when lid closes")
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }

                optionRow(title: isKorean ? "핫스팟" : "Hotspot", topic: .networkRecovery) {
                    HStack(spacing: 10) {
                        Toggle("", isOn: $appState.networkRecoveryEnabled)
                            .labelsHidden()
                        TextField(isKorean ? "핫스팟 이름" : "Hotspot name", text: $appState.networkRecoverySSIDText)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 150)
                            .disabled(!appState.networkRecoveryEnabled)
                        Picker("", selection: networkRecoveryRetryBinding) {
                            Text("15s").tag(15)
                            Text("30s").tag(30)
                            Text("1m").tag(60)
                            Text("3m").tag(180)
                        }
                        .labelsHidden()
                        .frame(width: 78)
                        .disabled(!appState.networkRecoveryEnabled)
                        Text(appState.networkRecoveryStatusTitle)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }

                Divider()

                optionRow(title: isKorean ? "자동 실행" : "Launch") {
                    HStack(spacing: 10) {
                        Toggle("", isOn: $appState.launchAtLoginEnabled)
                            .labelsHidden()
                        Text(appState.launchAtLoginStatusTitle)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }

                optionRow(title: isKorean ? "알림" : "Alerts") {
                    HStack(spacing: 10) {
                        Button(appState.notificationPermissionButtonTitle) {
                            appState.requestNotificationPermission()
                        }
                    }
                }

                optionRow(title: isKorean ? "업데이트" : "Updates") {
                    HStack(spacing: 10) {
                        Button(appState.checkForUpdatesTitle) {
                            updateController.checkForUpdates()
                        }
                        .disabled(updateController.isConfigured && !updateController.canCheckForUpdates)
                        Text(updateController.statusTitle(language: appState.language))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }

                optionRow(title: isKorean ? "자동 업데이트" : "Auto Update") {
                    HStack(spacing: 10) {
                        Toggle("", isOn: Binding(
                            get: { updateController.automaticUpdatesEnabled },
                            set: { updateController.setAutomaticUpdates($0) }
                        ))
                        .labelsHidden()
                        .disabled(!updateController.isConfigured)
                        Text(updateController.automaticUpdatesTitle(language: appState.language))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }

                optionRow(title: appState.languageTitle) {
                    Picker("", selection: $appState.language) {
                        ForEach(AppLanguage.allCases) { language in
                            Text(language.title).tag(language)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                    .frame(width: 140)
                }

                optionRow(title: isKorean ? "피드백" : "Feedback") {
                    HStack(spacing: 10) {
                        Menu(isKorean ? "피드백/버그 리포트" : "Feedback & Bug Report") {
                            Button(isKorean ? "버그 제보" : "Report a Bug") {
                                appState.openBugReport()
                            }
                            .keyboardShortcut("b", modifiers: [.command, .shift])
                            Button(isKorean ? "기능 제안" : "Request a Feature") {
                                appState.openFeatureRequest()
                            }
                            .keyboardShortcut("f", modifiers: [.command, .shift])
                            Divider()
                            Button(isKorean ? "GitHub Issues 보기" : "Open GitHub Issues") {
                                appState.openGitHubIssues()
                            }
                            .keyboardShortcut("i", modifiers: [.command, .shift])
                        }
                        Text(isKorean ? "GitHub Issue로 남겨주세요" : "Opens GitHub Issues")
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }

                optionRow(title: isKorean ? "개발자 모드" : "Developer Mode") {
                    HStack(spacing: 10) {
                        Toggle("", isOn: $appState.developerModeEnabled)
                            .labelsHidden()
                        Text(appState.developerModeEnabled
                             ? (isKorean ? "디버그 로그 표시" : "Shows debug logs")
                             : (isKorean ? "디버그 로그 숨김" : "Hides debug logs"))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }

                if appState.developerModeEnabled {
                    optionRow(title: isKorean ? "디버그" : "Debug") {
                        debugLogView
                    }
                }

                optionRow(title: isKorean ? "정보" : "About") {
                    HStack(spacing: 10) {
                        Button(isKorean ? "LidStay 정보" : "About LidStay") {
                            appState.showAbout()
                        }
                        Text(isKorean ? "버전, 연락처, GitHub" : "Version, contact, GitHub")
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }

                optionRow(title: isKorean ? "제거" : "Remove", topic: .uninstall) {
                    HStack(spacing: 10) {
                        Button(role: .destructive) {
                            appState.confirmAndUninstall()
                        } label: {
                            Text(isKorean ? "LidStay 제거" : "Remove LidStay")
                        }
                        Text(isKorean ? "앱과 터미널 명령어 삭제" : "Delete app and CLI")
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
            }

            Spacer(minLength: 0)
        }
        .padding(22)
        .frame(width: 620, height: optionsWindowHeight)
        .popover(item: $helpTopic) { topic in
            VStack(alignment: .leading, spacing: 8) {
                Text(topic.title(isKorean: isKorean))
                    .font(.headline)
                Text(topic.message(isKorean: isKorean))
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(14)
            .frame(width: 300, alignment: .leading)
        }
    }

    private func optionRow<Content: View>(
        title: String,
        topic: HelpTopic? = nil,
        @ViewBuilder content: () -> Content
    ) -> some View {
        HStack(alignment: .center, spacing: 14) {
            HStack(spacing: 6) {
                Text(title)
                    .font(.body)
                if let topic {
                    helpButton(topic)
                }
            }
            .frame(width: 104, alignment: .leading)

            content()
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func helpButton(_ topic: HelpTopic) -> some View {
        Button {
            helpTopic = topic
        } label: {
            Image(systemName: "questionmark.circle")
                .imageScale(.small)
        }
        .buttonStyle(.borderless)
        .frame(width: 20)
        .help(topic.title(isKorean: isKorean))
    }

    private var batteryProtectionSummary: String {
        if !isBatteryConditionSelected {
            return isKorean ? "전원 연결 조건에서는 사용 안 함" : "Off for power adapter condition"
        }

        if appState.autoPauseOnLowBattery {
            return isKorean ? "\(appState.lowBatteryLimit)% 이하에서 잠깐 중지" : "Pause at \(appState.lowBatteryLimit)% or below"
        }

        return isKorean ? "사용 안 함" : "Off"
    }

    private var batteryThresholdTitle: String {
        isKorean ? "배터리 \(appState.lowBatteryLimit)% 이상" : "Battery \(appState.lowBatteryLimit)%+"
    }

    private var batteryUnlimitedTitle: String {
        isKorean ? "배터리 포함" : "Include battery"
    }

    private var isBatteryConditionSelected: Bool {
        appState.allowOnBattery
    }

    private var powerConditionBinding: Binding<PowerCondition> {
        Binding(
            get: {
                appState.allowOnBattery ? .battery : .powerAdapter
            },
            set: { condition in
                appState.allowOnBattery = condition == .battery
            }
        )
    }

    private var lowBatteryLimitBinding: Binding<Double> {
        Binding(
            get: {
                Double(appState.lowBatteryLimit)
            },
            set: { value in
                appState.selectLowBatteryLimit(Int(value.rounded()))
            }
        )
    }

    private var networkRecoveryRetryBinding: Binding<Int> {
        Binding(
            get: {
                appState.networkRecoveryRetrySeconds
            },
            set: { seconds in
                appState.selectNetworkRecoveryRetrySeconds(seconds)
            }
        )
    }

    private var optionsWindowHeight: CGFloat {
        appState.developerModeEnabled ? 760 : 650
    }

    private var debugLogView: some View {
        VStack(alignment: .leading, spacing: 8) {
            if appState.debugEvents.isEmpty {
                Text(appState.debugLogEmptyTitle)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 6) {
                        ForEach(Array(appState.debugEvents.prefix(8))) { event in
                            HStack(alignment: .top, spacing: 6) {
                                Image(systemName: event.succeeded ? "checkmark.circle.fill" : "xmark.circle.fill")
                                    .foregroundStyle(event.succeeded ? Color.green : Color.red)
                                    .imageScale(.small)
                                    .frame(width: 16)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("\(event.timeText) \(event.title)")
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(.secondary)
                                    Text(event.detail)
                                        .font(.caption.monospaced())
                                        .lineLimit(2)
                                        .textSelection(.enabled)
                                }
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(height: 118)
            }

            HStack(spacing: 10) {
                Text(appState.debugLogFileHint)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Button(appState.clearDebugLogTitle) {
                    appState.clearDebugEvents()
                }
                .disabled(appState.debugEvents.isEmpty)
            }
        }
    }
}

private enum PowerCondition: Hashable {
    case powerAdapter
    case battery
}

private enum HelpTopic: Identifiable {
    case powerCondition
    case batteryProtection
    case batteryLimit
    case launchAtLogin
    case notifications
    case updates
    case automaticUpdates
    case networkRecovery
    case language
    case about
    case uninstall

    var id: Self { self }

    func title(isKorean: Bool) -> String {
        switch self {
        case .powerCondition:
            return isKorean ? "실행 조건" : "Power condition"
        case .batteryProtection:
            return isKorean ? "배터리 보호" : "Battery protection"
        case .batteryLimit:
            return isKorean ? "배터리 기준" : "Battery limit"
        case .launchAtLogin:
            return isKorean ? "로그인 시 자동 실행" : "Open at login"
        case .notifications:
            return isKorean ? "알림" : "Alerts"
        case .updates:
            return isKorean ? "업데이트" : "Updates"
        case .automaticUpdates:
            return isKorean ? "자동 업데이트" : "Automatic updates"
        case .networkRecovery:
            return isKorean ? "핫스팟 자동 연결" : "Auto-connect hotspot"
        case .language:
            return isKorean ? "언어" : "Language"
        case .about:
            return isKorean ? "정보" : "About"
        case .uninstall:
            return isKorean ? "제거" : "Remove"
        }
    }

    func message(isKorean: Bool) -> String {
        switch self {
        case .powerCondition:
            return isKorean
                ? "Mac 켜두기를 전원 연결 시에만 실행할지, 배터리 기준을 적용해 실행할지 정합니다."
                : "Choose whether LidStay runs only on power adapter or also under the battery limit."
        case .batteryProtection:
            return isKorean
                ? "배터리가 기준 이하로 내려가면 세션은 유지하되 실제 Mac 켜두기는 잠깐 중지합니다."
                : "When battery falls to the limit, the session remains visible but sleep prevention pauses."
        case .batteryLimit:
            return isKorean
                ? "슬라이더로 정한 퍼센트 이하에서는 배터리 보호가 동작합니다."
                : "Battery protection activates at or below the percentage selected on the slider."
        case .launchAtLogin:
            return isKorean
                ? "macOS에 로그인한 뒤 LidStay를 자동으로 다시 엽니다."
                : "Reopens LidStay automatically after you log in to macOS."
        case .notifications:
            return isKorean
                ? "세션 시간이 끝나거나 실행 중이던 Mac 켜두기가 잠깐 중지되면 알림을 보냅니다."
                : "Sends an alert when a session ends or active sleep prevention pauses."
        case .updates:
            return isKorean
                ? "지금 새 버전이 있는지 확인합니다. 릴리스 설정이 끝나기 전에는 GitHub 릴리스 페이지를 엽니다."
                : "Checks for a new version now. Before release setup is complete, this opens GitHub Releases."
        case .automaticUpdates:
            return isKorean
                ? "켜두면 새 버전을 자동으로 확인하고 가능한 경우 자동으로 설치합니다. 권한이 필요하면 macOS가 확인을 요청할 수 있습니다."
                : "When enabled, LidStay checks for updates and installs them automatically when possible. macOS may still ask when authorization is required."
        case .networkRecovery:
            return isKorean
                ? "Mac 켜두는 중 네트워크가 끊기면, 이전에 연결해 둔 핫스팟 이름으로 자동 연결을 시도합니다."
                : "When the network drops while LidStay is keeping your Mac on, it tries to join the hotspot name you entered. Join it once in macOS first."
        case .language:
            return isKorean
                ? "메뉴와 옵션 창의 표시 언어를 바꿉니다."
                : "Changes the display language for the menu and options window."
        case .about:
            return isKorean
                ? "앱 버전, 연락처, GitHub 릴리스 링크를 확인합니다."
                : "Shows app version, contact, and GitHub release links."
        case .uninstall:
            return isKorean
                ? "Launchpad에서 삭제 표시가 보이지 않는 경우에도 앱 안에서 LidStay를 제거할 수 있습니다."
                : "Removes LidStay from inside the app even when Launchpad does not show a delete button."
        }
    }
}

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
                }

                optionRow(title: isKorean ? "배터리 기준" : "Limit", topic: .batteryLimit) {
                    HStack(spacing: 8) {
                        TextField("", text: $appState.lowBatteryLimitText)
                            .frame(width: 48)
                            .multilineTextAlignment(.trailing)
                            .onSubmit {
                                appState.selectLowBatteryLimit(appState.lowBatteryLimit)
                            }
                        Text("%")
                            .foregroundStyle(.secondary)
                        ForEach(AppState.lowBatteryLimitOptions, id: \.self) { limit in
                            Button("\(limit)%") {
                                appState.selectLowBatteryLimit(limit)
                            }
                            .buttonStyle(.borderless)
                        }
                    }
                    .disabled(!appState.autoPauseOnLowBattery)
                }

                Divider()

                optionRow(title: isKorean ? "자동 실행" : "Launch", topic: .launchAtLogin) {
                    HStack(spacing: 10) {
                        Toggle("", isOn: $appState.launchAtLoginEnabled)
                            .labelsHidden()
                        Text(appState.launchAtLoginStatusTitle)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }

                optionRow(title: isKorean ? "업데이트" : "Updates", topic: .updates) {
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

                optionRow(title: isKorean ? "자동 업데이트" : "Auto Update", topic: .automaticUpdates) {
                    HStack(spacing: 10) {
                        Toggle("", isOn: Binding(
                            get: { updateController.automaticallyChecksForUpdates },
                            set: { updateController.setAutomaticallyChecksForUpdates($0) }
                        ))
                        .labelsHidden()
                        .disabled(!updateController.isConfigured)
                        Text(isKorean ? "새 버전 자동 확인" : "Check automatically")
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }

                optionRow(title: isKorean ? "자동 설치" : "Auto Install", topic: .automaticInstall) {
                    HStack(spacing: 10) {
                        Toggle("", isOn: Binding(
                            get: { updateController.automaticallyDownloadsUpdates },
                            set: { updateController.setAutomaticallyDownloadsUpdates($0) }
                        ))
                        .labelsHidden()
                        .disabled(!updateController.isConfigured || !updateController.automaticallyChecksForUpdates || !updateController.allowsAutomaticUpdates)
                        Text(updateController.automaticInstallTitle(language: appState.language))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }

                optionRow(title: appState.languageTitle, topic: .language) {
                    Picker("", selection: $appState.language) {
                        ForEach(AppLanguage.allCases) { language in
                            Text(language.title).tag(language)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                    .frame(width: 140)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(22)
        .frame(width: 520, height: 430)
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
        topic: HelpTopic,
        @ViewBuilder content: () -> Content
    ) -> some View {
        HStack(alignment: .center, spacing: 14) {
            HStack(spacing: 6) {
                Text(title)
                    .font(.body)
                helpButton(topic)
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
    case updates
    case automaticUpdates
    case automaticInstall
    case language

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
        case .updates:
            return isKorean ? "업데이트" : "Updates"
        case .automaticUpdates:
            return isKorean ? "자동 업데이트" : "Automatic updates"
        case .automaticInstall:
            return isKorean ? "자동 설치" : "Automatic install"
        case .language:
            return isKorean ? "언어" : "Language"
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
                ? "이 퍼센트 이하에서는 배터리 보호가 동작합니다. 1부터 95 사이 숫자를 사용할 수 있습니다."
                : "Battery protection activates at or below this percentage. Values from 1 to 95 are allowed."
        case .launchAtLogin:
            return isKorean
                ? "macOS에 로그인한 뒤 LidStay를 자동으로 다시 엽니다."
                : "Reopens LidStay automatically after you log in to macOS."
        case .updates:
            return isKorean
                ? "지금 새 버전이 있는지 확인합니다. 릴리스 설정이 끝나기 전에는 GitHub 릴리스 페이지를 엽니다."
                : "Checks for a new version now. Before release setup is complete, this opens GitHub Releases."
        case .automaticUpdates:
            return isKorean
                ? "켜두면 LidStay가 백그라운드에서 새 버전을 자동으로 확인합니다."
                : "When enabled, LidStay checks for new versions in the background."
        case .automaticInstall:
            return isKorean
                ? "켜두면 가능한 업데이트를 자동으로 내려받고 설치합니다. 권한이 필요하면 macOS가 확인을 요청할 수 있습니다."
                : "When enabled, LidStay downloads and installs updates when possible. macOS may still ask when authorization is required."
        case .language:
            return isKorean
                ? "메뉴와 옵션 창의 표시 언어를 바꿉니다."
                : "Changes the display language for the menu and options window."
        }
    }
}

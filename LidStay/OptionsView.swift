import SwiftUI

struct OptionsView: View {
    @EnvironmentObject private var appState: AppState
    @State private var helpTopic: HelpTopic?

    private var isKorean: Bool {
        appState.language == .korean
    }

    var body: some View {
        TabView {
            powerTab
                .tabItem {
                    Label(isKorean ? "실행 조건" : "Condition", systemImage: "powerplug")
                }

            batteryTab
                .tabItem {
                    Label(isKorean ? "배터리" : "Battery", systemImage: "battery.50")
                }

            appTab
                .tabItem {
                    Label(isKorean ? "앱" : "App", systemImage: "gearshape")
                }
        }
        .padding(18)
        .frame(width: 520, height: 360)
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

    private var powerTab: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    helpRow(title: powerConditionTitle, topic: .powerCondition)

                    Picker(powerConditionTitle, selection: powerConditionBinding) {
                        Text(isKorean ? "전원 연결 중에만 허용" : "Only while power adapter is connected")
                            .tag(PowerCondition.powerAdapter)
                        Text(appState.autoPauseOnLowBattery ? batteryThresholdTitle : batteryUnlimitedTitle)
                            .tag(PowerCondition.battery)
                    }
                    .labelsHidden()
                    .pickerStyle(.radioGroup)
                }

                Text(appState.powerModeStatusTitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } header: {
                Text(isKorean ? "실행 조건" : "Power Condition")
            }
        }
        .formStyle(.grouped)
        .padding(.top, 4)
    }

    private var batteryTab: some View {
        Form {
            Section {
                HStack {
                    Toggle(isKorean ? "배터리 보호 사용" : "Use battery protection", isOn: $appState.autoPauseOnLowBattery)
                    Spacer(minLength: 12)
                    helpButton(.batteryProtection)
                }

                HStack {
                    Text(isKorean ? "기준" : "Limit")
                    Spacer(minLength: 12)
                    TextField("", text: $appState.lowBatteryLimitText)
                        .frame(width: 56)
                        .multilineTextAlignment(.trailing)
                        .onSubmit {
                            appState.selectLowBatteryLimit(appState.lowBatteryLimit)
                        }
                        .disabled(!appState.autoPauseOnLowBattery)
                    Text("%")
                        .foregroundStyle(.secondary)
                        .fixedSize()
                    helpButton(.batteryLimit)
                }

                HStack {
                    ForEach(AppState.lowBatteryLimitOptions, id: \.self) { limit in
                        Button("\(limit)%") {
                            appState.selectLowBatteryLimit(limit)
                        }
                    }
                }
                .disabled(!appState.autoPauseOnLowBattery)
            } header: {
                Text(isKorean ? "배터리 보호" : "Battery Protection")
            }
        }
        .formStyle(.grouped)
        .padding(.top, 4)
    }

    private var appTab: some View {
        Form {
            Section {
                HStack {
                    Toggle(appState.launchAtLoginTitle, isOn: $appState.launchAtLoginEnabled)
                    Spacer(minLength: 12)
                    helpButton(.launchAtLogin)
                }

                HStack {
                    Text(appState.languageTitle)
                    Spacer(minLength: 12)
                    Picker(appState.languageTitle, selection: $appState.language) {
                        ForEach(AppLanguage.allCases) { language in
                            Text(language.title).tag(language)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                    .frame(width: 140)
                    helpButton(.language)
                }
            } header: {
                Text(isKorean ? "앱 설정" : "App Settings")
            }
        }
        .formStyle(.grouped)
        .padding(.top, 4)
    }

    private func helpRow(title: String, topic: HelpTopic) -> some View {
        HStack {
            Text(title)
            Spacer(minLength: 12)
            helpButton(topic)
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

    private var powerConditionTitle: String {
        isKorean ? "조건" : "Condition"
    }

    private var batteryThresholdTitle: String {
        isKorean ? "배터리 \(appState.lowBatteryLimit)% 이상일 때 허용" : "Battery above \(appState.lowBatteryLimit)%"
    }

    private var batteryUnlimitedTitle: String {
        isKorean ? "배터리 제한 없이 허용" : "No battery limit"
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
        case .language:
            return isKorean ? "언어" : "Language"
        }
    }

    func message(isKorean: Bool) -> String {
        switch self {
        case .powerCondition:
            return isKorean
                ? "Mac 켜두기 세션을 전원 연결 중에만 유지할지, 배터리 사용 중에도 허용할지 정합니다."
                : "Controls whether Keep Mac On runs only on power adapter or may also run on battery."
        case .batteryProtection:
            return isKorean
                ? "배터리가 설정한 기준 이하로 내려가면 세션은 켜져 있어도 실제 전원 유지는 잠깐 중지합니다."
                : "When battery falls below the selected limit, the session remains on but sleep prevention pauses."
        case .batteryLimit:
            return isKorean
                ? "이 퍼센트 이하에서는 배터리 보호가 동작합니다. 1부터 95 사이 숫자를 사용할 수 있습니다."
                : "Battery protection activates at or below this percentage. Values from 1 to 95 are allowed."
        case .launchAtLogin:
            return isKorean
                ? "macOS에 로그인한 뒤 LidStay를 자동으로 다시 엽니다."
                : "Reopens LidStay automatically after you log in to macOS."
        case .language:
            return isKorean
                ? "메뉴와 옵션 창의 표시 언어를 바꿉니다."
                : "Changes the display language for the menu and options window."
        }
    }
}

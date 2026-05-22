import SwiftUI

struct OptionsView: View {
    @EnvironmentObject private var appState: AppState

    private var isKorean: Bool {
        appState.language == .korean
    }

    var body: some View {
        Form {
            Section {
                Picker(powerConditionTitle, selection: powerConditionBinding) {
                    Text(isKorean ? "전원 연결 중에만 허용" : "Only while power adapter is connected")
                        .tag(PowerCondition.powerAdapter)
                    Text(appState.autoPauseOnLowBattery ? batteryThresholdTitle : batteryUnlimitedTitle)
                        .tag(PowerCondition.battery)
                }
                .pickerStyle(.radioGroup)

                Text(appState.powerModeStatusTitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } header: {
                Text(isKorean ? "실행 조건" : "Power Condition")
            }

            Section {
                Toggle(isKorean ? "배터리 보호 사용" : "Use battery protection", isOn: $appState.autoPauseOnLowBattery)

                HStack {
                    Text(isKorean ? "기준" : "Limit")
                    TextField(appState.percentPlaceholder, text: $appState.lowBatteryLimitText)
                        .frame(width: 64)
                        .multilineTextAlignment(.trailing)
                        .onSubmit {
                            appState.selectLowBatteryLimit(appState.lowBatteryLimit)
                        }
                    Text("%")
                        .foregroundStyle(.secondary)
                }
                .disabled(!appState.autoPauseOnLowBattery)

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

            Section {
                Toggle(appState.launchAtLoginTitle, isOn: $appState.launchAtLoginEnabled)

                Picker(appState.languageTitle, selection: $appState.language) {
                    ForEach(AppLanguage.allCases) { language in
                        Text(language.title).tag(language)
                    }
                }
                .pickerStyle(.menu)
            } header: {
                Text(isKorean ? "앱 설정" : "App Settings")
            }
        }
        .formStyle(.grouped)
        .padding(18)
        .frame(width: 460)
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

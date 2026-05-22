import AppKit
import SwiftUI

struct MenuBarView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        statusItem

        Divider()

        Button {
            let newValue = !appState.isSleepPreventionEnabled
            guard !newValue || appState.canToggleSleepPrevention else {
                return
            }
            appState.isSleepPreventionEnabled = newValue
        } label: {
            if appState.isSleepPreventionEnabled {
                Label(appState.stopAwakeTitle, systemImage: "stop.circle")
            } else {
                Text(appState.awakeToggleTitle)
            }
        }

        Menu(appState.timeMenuTitle) {
            ForEach(AppState.durationOptions) { option in
                Button {
                    appState.selectDuration(option)
                } label: {
                    if appState.selectedDurationID == option.id {
                        Label(appState.durationTitle(for: option), systemImage: "checkmark")
                    } else {
                        Text(appState.durationTitle(for: option))
                    }
                }
            }
        }

        if appState.isSleepPreventionEnabled {
            Text(appState.endTimeText)
        }

        Divider()

        Text(appState.powerModeStatusTitle)
        Button(appState.powerModeActionTitle) {
            appState.allowOnBattery.toggle()
        }

        Text(appState.launchAtLoginStatusTitle)
        Button(appState.launchAtLoginActionTitle) {
            appState.launchAtLoginEnabled.toggle()
        }

        Menu(appState.languageTitle) {
            ForEach(AppLanguage.allCases) { language in
                Button {
                    appState.language = language
                } label: {
                    if appState.language == language {
                        Label(language.title, systemImage: "checkmark")
                    } else {
                        Text(language.title)
                    }
                }
            }
        }

        Divider()

        Button(appState.aboutTitle) {
            appState.showAbout()
        }

        Button(appState.quitTitle) {
            appState.shutdown()
            NSApplication.shared.terminate(nil)
        }
    }

    private var statusItem: some View {
        Button {
        } label: {
            Label(appState.sessionSummaryText, systemImage: appState.statusIndicatorSymbolName)
        }
        .disabled(true)
    }

}

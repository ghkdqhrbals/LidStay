import AppKit
import SwiftUI

struct MenuBarView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var updateController: UpdateController

    var body: some View {
        statusItem

        Divider()

        Button {
            let newValue = !appState.isSleepPreventionEnabled
            guard !newValue || appState.canToggleSleepPrevention else {
                return
            }
            appState.setSleepPreventionEnabled(newValue)
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

        Button(appState.optionsTitle) {
            appState.showOptions()
        }

        Divider()

        Button(appState.checkForUpdatesTitle) {
            updateController.checkForUpdates()
        }
        .disabled(updateController.isConfigured && !updateController.canCheckForUpdates)

        Button(appState.aboutTitle) {
            appState.showAbout()
        }

        Button(appState.quitTitle) {
            appState.shutdown()
            NSApplication.shared.terminate(nil)
        }
    }

    private var statusItem: some View {
        Label(appState.menuStatusText, image: appState.statusDotImageName)
            .labelStyle(.titleAndIcon)
    }
}

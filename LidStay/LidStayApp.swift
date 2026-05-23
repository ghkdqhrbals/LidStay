import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var appState: AppState?
    private var statusItemController: StatusItemController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        let appState = AppState()
        self.appState = appState
        statusItemController = StatusItemController(appState: appState)
        _ = UpdateController.shared
    }

    func applicationWillTerminate(_ notification: Notification) {
        appState?.shutdown()
    }
}

@main
struct LidStayApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}

import AppKit
import SwiftUI

@main
struct LidStayApp: App {
    @StateObject private var appState = AppState()
    @StateObject private var updateController = UpdateController.shared

    var body: some Scene {
        MenuBarExtra {
            MenuBarView()
                .environmentObject(appState)
                .environmentObject(updateController)
                .onAppear {
                    NSApp.setActivationPolicy(.accessory)
                }
        } label: {
            Image(appState.menuBarIconName)
                .resizable()
                .renderingMode(.template)
                .frame(width: appState.menuBarIconSize, height: appState.menuBarIconSize)
        }
    }
}

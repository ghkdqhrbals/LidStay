import AppKit
import SwiftUI

@main
struct LidStayApp: App {
    @StateObject private var appState = AppState()

    var body: some Scene {
        MenuBarExtra {
            MenuBarView()
                .environmentObject(appState)
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

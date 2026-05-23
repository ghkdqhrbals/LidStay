import AppKit
import SwiftUI

@MainActor
final class OptionsWindowController {
    static let shared = OptionsWindowController()

    private var window: NSWindow?

    func show(appState: AppState) {
        let title = appState.language == .korean ? "LidStay 옵션" : "LidStay Options"
        let rootView = OptionsView()
            .environmentObject(appState)
            .environmentObject(UpdateController.shared)

        if let window {
            window.title = title
            window.contentView = NSHostingView(rootView: rootView)
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 520, height: 430),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = title
        window.contentView = NSHostingView(rootView: rootView)
        window.center()
        window.isReleasedWhenClosed = false
        self.window = window

        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}

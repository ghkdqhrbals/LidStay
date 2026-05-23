import AppKit
import SwiftUI

@MainActor
final class OptionsWindowController {
    static let shared = OptionsWindowController()

    private var window: NSPanel?

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

        let window = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 520, height: 430),
            styleMask: [.titled, .closable, .utilityWindow],
            backing: .buffered,
            defer: false
        )
        window.title = title
        window.contentView = NSHostingView(rootView: rootView)
        window.center()
        window.hidesOnDeactivate = false
        window.isFloatingPanel = true
        window.isReleasedWhenClosed = false
        window.level = .floating
        window.collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary]
        self.window = window

        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func bringForwardIfVisible() {
        guard let window, window.isVisible else {
            return
        }

        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func keepVisibleWhileSystemSettingsIsOpen() {
        for delay in [0.2, 0.8, 1.6, 3.0] {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                guard let window = self?.window, window.isVisible else {
                    return
                }

                window.orderFrontRegardless()
            }
        }
    }
}

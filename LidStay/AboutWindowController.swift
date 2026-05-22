import AppKit
import SwiftUI

final class AboutWindowController {
    static let shared = AboutWindowController()

    private var window: NSWindow?

    func show(language: AppLanguage) {
        if let window {
            window.title = language == .korean ? "LidStay 정보" : "About LidStay"
            window.contentView = NSHostingView(rootView: AboutView(language: language))
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 460, height: 330),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = language == .korean ? "LidStay 정보" : "About LidStay"
        window.contentView = NSHostingView(rootView: AboutView(language: language))
        window.center()
        window.isReleasedWhenClosed = false
        self.window = window

        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}

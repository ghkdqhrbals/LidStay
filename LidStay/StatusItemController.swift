import AppKit
import Combine

@MainActor
final class StatusItemController: NSObject, NSMenuDelegate {
    private let appState: AppState
    private let statusItem: NSStatusItem
    private var cancellable: AnyCancellable?

    init(appState: AppState) {
        self.appState = appState
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        super.init()

        configureButton()
        updateIcon()
        cancellable = appState.objectWillChange.sink { [weak self] _ in
            Task { @MainActor in
                self?.updateIcon()
            }
        }
    }

    private func configureButton() {
        guard let button = statusItem.button else {
            return
        }

        button.target = self
        button.action = #selector(handleClick(_:))
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
    }

    @objc private func handleClick(_ sender: NSStatusBarButton) {
        guard let event = NSApp.currentEvent else {
            return
        }

        switch event.type {
        case .rightMouseUp:
            showMenu()
        case .leftMouseUp:
            toggleSession()
        default:
            return
        }
    }

    private func toggleSession() {
        let newValue = !appState.isSleepPreventionEnabled
        guard !newValue || appState.canToggleSleepPrevention else {
            NSSound.beep()
            return
        }

        appState.setSleepPreventionEnabled(newValue)
    }

    private func showMenu() {
        let menu = makeMenu()
        menu.delegate = self
        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        statusItem.menu = nil
    }

    func menuWillOpen(_ menu: NSMenu) {
        appState.menuBarMenuDidOpen()
    }

    func menuDidClose(_ menu: NSMenu) {
        appState.menuBarMenuDidClose()
    }

    private func updateIcon() {
        guard let button = statusItem.button else {
            return
        }

        let image = NSImage(named: appState.menuBarIconName)
        image?.isTemplate = true
        image?.size = NSSize(width: appState.menuBarIconSize, height: appState.menuBarIconSize)
        button.image = image
        button.imagePosition = .imageOnly
        button.toolTip = appState.menuStatusText
    }

    private func makeMenu() -> NSMenu {
        let menu = NSMenu()
        menu.autoenablesItems = false

        let statusItem = NSMenuItem(title: appState.menuStatusText, action: nil, keyEquivalent: "")
        statusItem.image = NSImage(named: appState.statusDotImageName)
        statusItem.isEnabled = false
        menu.addItem(statusItem)
        menu.addItem(.separator())

        if appState.isSleepPreventionEnabled {
            menu.addItem(makeItem(
                title: appState.stopAwakeTitle,
                image: NSImage(systemSymbolName: "stop.circle", accessibilityDescription: nil),
                action: #selector(stopSession)
            ))
        } else {
            let item = makeItem(title: appState.awakeToggleTitle, action: #selector(startSession))
            item.isEnabled = appState.canToggleSleepPrevention
            menu.addItem(item)
        }

        let timeMenuItem = NSMenuItem(title: appState.timeMenuTitle, action: nil, keyEquivalent: "")
        let timeMenu = NSMenu()
        for option in AppState.durationOptions {
            let item = NSMenuItem(
                title: appState.durationTitle(for: option),
                action: #selector(selectDuration(_:)),
                keyEquivalent: ""
            )
            item.target = self
            item.representedObject = option.id
            item.state = appState.selectedDurationID == option.id ? .on : .off
            timeMenu.addItem(item)
        }
        timeMenuItem.submenu = timeMenu
        menu.addItem(timeMenuItem)

        if appState.isSleepPreventionEnabled {
            let endTimeItem = NSMenuItem(title: appState.endTimeText, action: nil, keyEquivalent: "")
            endTimeItem.isEnabled = false
            menu.addItem(endTimeItem)
        }

        menu.addItem(.separator())
        menu.addItem(makeItem(title: appState.optionsTitle, action: #selector(showOptions)))
        menu.addItem(makeItem(title: appState.aboutTitle, action: #selector(showAbout)))
        menu.addItem(makeItem(title: appState.quitTitle, action: #selector(quit)))

        return menu
    }

    private func makeItem(title: String, image: NSImage? = nil, action: Selector) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
        item.target = self
        item.image = image
        return item
    }

    @objc private func startSession() {
        appState.setSleepPreventionEnabled(true)
    }

    @objc private func stopSession() {
        appState.setSleepPreventionEnabled(false)
    }

    @objc private func selectDuration(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? String,
              let option = AppState.durationOptions.first(where: { $0.id == id }) else {
            return
        }

        appState.selectDuration(option)
    }

    @objc private func showOptions() {
        appState.showOptions()
    }

    @objc private func showAbout() {
        appState.showAbout()
    }

    @objc private func quit() {
        appState.shutdown()
        NSApplication.shared.terminate(nil)
    }
}

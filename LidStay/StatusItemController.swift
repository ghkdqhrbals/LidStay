import AppKit
import Combine

@MainActor
final class StatusItemController: NSObject, NSMenuDelegate {
    private let appState: AppState
    private let statusItem: NSStatusItem
    private var cancellables = Set<AnyCancellable>()

    init(appState: AppState) {
        self.appState = appState
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        super.init()
        configureButton()
        observeAppState()
        updateIcon()
    }

    private func configureButton() {
        guard let button = statusItem.button else {
            return
        }

        button.target = self
        button.action = #selector(statusItemClicked(_:))
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
    }

    private func observeAppState() {
        appState.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                DispatchQueue.main.async {
                    self?.updateIcon()
                }
            }
            .store(in: &cancellables)
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

    @objc private func statusItemClicked(_ sender: NSStatusBarButton) {
        switch NSApp.currentEvent?.type {
        case .rightMouseUp:
            showMenu()
        default:
            toggleSession()
        }
    }

    private func toggleSession() {
        let newValue = !appState.isSleepPreventionEnabled
        guard !newValue || appState.canToggleSleepPrevention else {
            return
        }
        appState.setSleepPreventionEnabled(newValue)
    }

    private func showMenu() {
        let menu = makeMenu()
        menu.delegate = self
        statusItem.menu = menu
        statusItem.button?.performClick(nil)
    }

    func menuDidClose(_ menu: NSMenu) {
        statusItem.menu = nil
    }

    private func makeMenu() -> NSMenu {
        let menu = NSMenu()

        let statusItem = NSMenuItem(title: appState.menuStatusText, action: nil, keyEquivalent: "")
        statusItem.image = NSImage(named: appState.statusDotImageName)
        statusItem.isEnabled = false
        menu.addItem(statusItem)

        menu.addItem(.separator())

        if appState.isSleepPreventionEnabled {
            menu.addItem(makeItem(title: appState.stopAwakeTitle, action: #selector(stopSession)))
        } else {
            let item = makeItem(title: appState.awakeToggleTitle, action: #selector(startSession))
            item.isEnabled = appState.canToggleSleepPrevention
            menu.addItem(item)
        }

        let durationMenu = NSMenu()
        for option in AppState.durationOptions {
            let item = makeItem(
                title: appState.durationTitle(for: option),
                action: #selector(selectDuration(_:))
            )
            item.representedObject = option.id
            item.state = appState.selectedDurationID == option.id ? .on : .off
            durationMenu.addItem(item)
        }

        let durationItem = NSMenuItem(title: appState.timeMenuTitle, action: nil, keyEquivalent: "")
        durationItem.submenu = durationMenu
        menu.addItem(durationItem)

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

    private func makeItem(title: String, action: Selector) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
        item.target = self
        return item
    }

    @objc private func startSession() {
        guard appState.canToggleSleepPrevention else {
            return
        }
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

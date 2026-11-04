import AppKit
import PedalboardCore
import ServiceManagement

/// The menu bar icon. A click toggles the pedal; a right-click (or
/// Control- or Option-click) opens the menu.
@MainActor
final class StatusItemController: NSObject {
    private let pedal: Pedal
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

    init(pedal: Pedal) {
        self.pedal = pedal
        super.init()
        if let button = statusItem.button {
            button.target = self
            button.action = #selector(clicked)
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
        pedal.onChange = { [weak self] in self?.update() }
        update()
    }

    // MARK: Icon

    private func update() {
        guard let button = statusItem.button else { return }
        let engaged = pedal.isEngaged
        let leaks = pedal.leaks
        let symbol = engaged ? "mic.slash.fill" : "mic.fill"
        let label = engaged ? "Microphones muted" : "Microphones on"
        let image = NSImage(systemSymbolName: symbol, accessibilityDescription: label)
        image?.isTemplate = true
        button.image = image
        // Red while muted, so a glance at the menu bar answers "can they hear
        // me?"; orange when something the pedal should mute still can't be.
        button.contentTintColor = if !engaged { nil } else if leaks.isEmpty { .systemRed } else { .systemOrange }
        button.toolTip =
            if !engaged {
                "\(label) — click to mute all but your live mics"
            } else if leaks.isEmpty {
                "\(label) — click to unmute"
            } else {
                "Still hearing you: \(leaks.map(\.name).formatted(.list(type: .and)))"
            }
    }

    // MARK: Clicks

    @objc private func clicked() {
        let event = NSApp.currentEvent
        let wantsMenu =
            event?.type == .rightMouseUp
            || event?.modifierFlags.contains(.control) == true
            || event?.modifierFlags.contains(.option) == true
        if wantsMenu {
            showMenu()
        } else {
            pedal.toggle()
        }
    }

    /// Attaches the menu only for as long as it is open: a status item with a
    /// menu opens it on every click, and the plain click has to toggle.
    private func showMenu() {
        pedal.reconcile()
        statusItem.menu = makeMenu()
        statusItem.button?.performClick(nil)
        statusItem.menu = nil
    }

    // MARK: Menu

    private func makeMenu() -> NSMenu {
        let menu = NSMenu()

        let toggle = NSMenuItem(title: "Mute Microphones", action: #selector(toggleEngaged), keyEquivalent: "")
        toggle.target = self
        toggle.state = pedal.isEngaged ? .on : .off
        toggle.subtitle = "Every mic but the live ones"
        menu.addItem(toggle)

        menu.addItem(.separator())
        menu.addItem(.sectionHeader(title: "Keep Live"))
        if pedal.devices.isEmpty {
            let none = NSMenuItem(title: "No microphones", action: nil, keyEquivalent: "")
            none.isEnabled = false
            menu.addItem(none)
        }
        for device in pedal.devices {
            let item = NSMenuItem(title: device.name, action: #selector(toggleLive(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = device.uid
            item.state = pedal.isLive(device) ? .on : .off
            item.subtitle = subtitle(for: device)
            menu.addItem(item)
        }

        menu.addItem(.separator())
        let login = NSMenuItem(title: "Open at Login", action: #selector(toggleLoginItem), keyEquivalent: "")
        login.target = self
        login.state = SMAppService.mainApp.status == .enabled ? .on : .off
        menu.addItem(login)
        let about = NSMenuItem(title: "About \(AppVariant.current.appName)", action: #selector(showAbout), keyEquivalent: "")
        about.target = self
        menu.addItem(about)
        menu.addItem(
            NSMenuItem(
                title: "Quit \(AppVariant.current.appName)",
                action: #selector(NSApplication.terminate(_:)),
                keyEquivalent: "q"))
        return menu
    }

    private func subtitle(for device: InputDevice) -> String? {
        if let failure = pedal.failures[device.uid] { return "Couldn't mute: \(failure)" }
        return switch pedal.state(of: device) {
        case .live: "Live"
        case .silenced: "Muted"
        case .open: nil
        case .unsilenceable: "Can't be muted — no mute or volume control"
        }
    }

    @objc private func toggleEngaged() {
        pedal.toggle()
    }

    @objc private func toggleLive(_ sender: NSMenuItem) {
        guard let uid = sender.representedObject as? String,
            let device = pedal.devices.first(where: { $0.uid == uid })
        else { return }
        pedal.setLive(!pedal.isLive(device), for: device)
    }

    @objc private func toggleLoginItem() {
        let service = SMAppService.mainApp
        do {
            if service.status == .enabled {
                try service.unregister()
            } else {
                try service.register()
            }
        } catch {
            NSAlert(error: error).runModal()
        }
    }

    @objc private func showAbout() {
        NSApp.activate()
        AboutPanel.show()
    }
}

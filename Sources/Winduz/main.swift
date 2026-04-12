import AppKit
import Carbon.HIToolbox
import Foundation
import WinduzCore

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    var statusItem: NSStatusItem!
    let menu = NSMenu()
    let windowController = FloatingWindowController()
    var watcher: FileWatcher?
    var hotKey: GlobalHotKey?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.title = "📁"

        menu.delegate = self
        statusItem.menu = menu
        rebuildMenu()

        watcher = FileWatcher(url: Store.shared.fileURL) {
            NotificationCenter.default.post(name: .winduzFavoritesChanged, object: nil)
        }
        watcher?.start()

        // ⌘⌥W: kVK_ANSI_W = 13, cmdKey | optionKey
        hotKey = GlobalHotKey(keyCode: 13, modifiers: UInt32(cmdKey | optionKey)) { [weak self] in
            self?.windowController.toggle()
        }
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        rebuildMenu()
    }

    private func rebuildMenu() {
        menu.removeAllItems()
        let favs = Store.shared.load()
        if favs.isEmpty {
            let empty = NSMenuItem(title: "No favorites — add with `wz add`", action: nil, keyEquivalent: "")
            empty.isEnabled = false
            menu.addItem(empty)
        } else {
            for fav in favs {
                let item = NSMenuItem(
                    title: "\(fav.name)  —  \(fav.path)",
                    action: #selector(openFavorite(_:)),
                    keyEquivalent: ""
                )
                item.target = self
                item.representedObject = fav.path
                menu.addItem(item)
            }
        }
        menu.addItem(.separator())
        let showItem = NSMenuItem(title: "Show Window", action: #selector(toggleWindow), keyEquivalent: "w")
        showItem.target = self
        menu.addItem(showItem)
        menu.addItem(NSMenuItem(
            title: "Quit Winduz",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        ))
    }

    @objc func toggleWindow() {
        windowController.toggle()
    }

    @objc func openFavorite(_ sender: NSMenuItem) {
        guard let path = sender.representedObject as? String else { return }
        Launcher.openPath(path)
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()

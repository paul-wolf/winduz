import AppKit
import SwiftUI
import WinduzCore

private func buildTimestamp() -> String {
    let raw = CommandLine.arguments.first ?? ""
    let path = (raw as NSString).resolvingSymlinksInPath
    NSLog("winduz: buildTimestamp path=\(path)")
    guard !path.isEmpty,
          let attrs = try? FileManager.default.attributesOfItem(atPath: path),
          let date = attrs[FileAttributeKey.modificationDate] as? Date else {
        return "[unknown build]"
    }
    let fmt = DateFormatter()
    fmt.dateFormat = "yyyy-MM-dd HH:mm:ss"
    return "[\(fmt.string(from: date))]"
}

final class FloatingWindowController {
    private var panel: NSPanel?

    func toggle() {
        if let panel, panel.isVisible, panel.isKeyWindow {
            panel.orderOut(nil)
        } else {
            show()
        }
    }

    func show() {
        if panel == nil { buildPanel() }
        panel?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func buildPanel() {
        let view = FavoritesView(
            onOpen: { path in
                Launcher.openPath(path)
            },
            onPinToggle: { [weak self] pinned in
                self?.panel?.level = pinned ? .floating : .normal
            },
            onEscape: { [weak self] in
                self?.panel?.orderOut(nil)
            }
        )
        let hosting = NSHostingView(rootView: view)

        let p = NSPanel(
            contentRect: NSRect(x: 200, y: 400, width: 320, height: 400),
            styleMask: [.titled, .closable, .resizable, .nonactivatingPanel, .utilityWindow],
            backing: .buffered,
            defer: false
        )
        p.title = "Winduz  \(buildTimestamp())"
        p.contentView = hosting
        p.level = .floating
        p.isFloatingPanel = true
        p.hidesOnDeactivate = false
        p.isReleasedWhenClosed = false
        p.setFrameAutosaveName("WinduzFloatingPanel")
        p.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel = p
    }
}

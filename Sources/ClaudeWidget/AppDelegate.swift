import AppKit
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
    var panel: NSPanel?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 260, height: 320),
            styleMask: [.nonactivatingPanel, .fullSizeContentView, .borderless],
            backing: .buffered,
            defer: false
        )
        panel.level = .floating
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.isMovableByWindowBackground = true
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary]

        if let saved = UserDefaults.standard.string(forKey: "widgetFrame") {
            let frame = NSRectFromString(saved)
            if frame != .zero {
                panel.setFrame(frame, display: false)
            } else {
                positionDefault(panel)
            }
        } else {
            positionDefault(panel)
        }

        let hosting = NSHostingView(rootView: ContentView())
        hosting.wantsLayer = true
        hosting.layer?.cornerRadius = 20
        hosting.layer?.masksToBounds = true
        panel.contentView = hosting
        panel.orderFront(nil)
        self.panel = panel

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(savePosition),
            name: NSWindow.didMoveNotification,
            object: panel
        )
    }

    private func positionDefault(_ panel: NSPanel) {
        guard let screen = NSScreen.main else { return }
        let sf = screen.visibleFrame
        panel.setFrameTopLeftPoint(NSPoint(x: sf.maxX - 275, y: sf.maxY))
    }

    @objc private func savePosition() {
        guard let panel else { return }
        UserDefaults.standard.set(NSStringFromRect(panel.frame), forKey: "widgetFrame")
    }
}

import AppKit
import SwiftUI

// Plain NSWindow that never becomes key/main, so it never pops above other windows.
class DesktopWindow: NSWindow {
    override var canBecomeKey: Bool  { false }
    override var canBecomeMain: Bool { false }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var window: DesktopWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let win = DesktopWindow(
            contentRect: NSRect(x: 0, y: 0, width: 260, height: 320),
            styleMask: [.borderless, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        // Sit at the desktop layer — every regular app window appears in front,
        // just like the macOS calendar widget.
        win.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.desktopWindow)) + 2)
        win.backgroundColor = .clear
        win.isOpaque = false
        win.hasShadow = true
        win.isMovableByWindowBackground = true
        win.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]

        if let saved = UserDefaults.standard.string(forKey: "widgetFrame") {
            let frame = NSRectFromString(saved)
            if frame != .zero {
                win.setFrame(frame, display: false)
            } else {
                positionDefault(win)
            }
        } else {
            positionDefault(win)
        }

        let hosting = NSHostingView(rootView: ContentView())
        hosting.wantsLayer = true
        hosting.layer?.cornerRadius = 20
        hosting.layer?.masksToBounds = true
        win.contentView = hosting
        win.orderFront(nil)
        self.window = win

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(savePosition),
            name: NSWindow.didMoveNotification,
            object: win
        )
    }

    private func positionDefault(_ win: NSWindow) {
        guard let screen = NSScreen.main else { return }
        let sf = screen.visibleFrame
        win.setFrameTopLeftPoint(NSPoint(x: sf.maxX - 275, y: sf.maxY))
    }

    @objc private func savePosition() {
        guard let window else { return }
        UserDefaults.standard.set(NSStringFromRect(window.frame), forKey: "widgetFrame")
    }
}

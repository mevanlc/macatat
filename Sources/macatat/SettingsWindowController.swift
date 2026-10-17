import AppKit
import SwiftUI

/// The single settings window. Closing it only hides it.
@MainActor
final class SettingsWindowController: NSObject, NSWindowDelegate {
    private let window: NSWindow
    /// Called when the window becomes key and every second while it's open, so the
    /// displayed permission state catches up with changes made in System Settings.
    private let onRefresh: @MainActor () -> Void
    private var refreshTimer: Timer?
    private var hasBeenShown = false

    init(rootView: some View, onRefresh: @escaping @MainActor () -> Void) {
        let hostingController = NSHostingController(rootView: rootView)
        hostingController.sizingOptions = .preferredContentSize
        window = NSWindow(contentViewController: hostingController)
        window.title = "macatat Settings"
        window.styleMask = [.titled, .closable]
        window.isReleasedWhenClosed = false
        self.onRefresh = onRefresh
        super.init()
        window.delegate = self
    }

    func show() {
        if !hasBeenShown {
            window.layoutIfNeeded()
            window.center()
            hasBeenShown = true
        }
        // Under macOS 14+ cooperative activation, a plain NSApp.activate() from a status
        // item click is refused, leaving an already-open window behind the active app.
        // The deprecated form still activates; orderFrontRegardless() at least raises the
        // window should a future macOS stop honoring it.
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()
    }

    func windowDidBecomeKey(_ notification: Notification) {
        onRefresh()
        guard refreshTimer == nil else { return }
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.onRefresh() }
        }
    }

    func windowWillClose(_ notification: Notification) {
        refreshTimer?.invalidate()
        refreshTimer = nil
    }
}

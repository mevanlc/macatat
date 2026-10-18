import AppKit

/// The menu-bar icon: theme-colored when idle, green while typing. A click opens
/// Settings; a right-click (or Control-click) shows a Settings…/Quit menu.
@MainActor
final class StatusItemController: NSObject {
    private let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private let contextMenu = NSMenu()
    private let onOpenSettings: @MainActor () -> Void

    var isTyping = false {
        didSet { item.button?.image = isTyping ? Self.typingImage : Self.idleImage }
    }

    var toolTip: String? {
        get { item.button?.toolTip }
        set { item.button?.toolTip = newValue }
    }

    init(onOpenSettings: @escaping @MainActor () -> Void) {
        self.onOpenSettings = onOpenSettings
        super.init()
        item.button?.image = Self.idleImage
        item.button?.target = self
        item.button?.action = #selector(clicked)
        item.button?.sendAction(on: [.leftMouseUp, .rightMouseDown])

        contextMenu.addItem(withTitle: "Settings…", action: #selector(openSettings), keyEquivalent: ",").target = self
        contextMenu.addItem(.separator())
        contextMenu.addItem(withTitle: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
            .target = NSApp
    }

    @objc private func clicked() {
        guard let event = NSApp.currentEvent else { return }
        if event.type == .rightMouseDown || event.modifierFlags.contains(.control) {
            showContextMenu()
        } else {
            onOpenSettings()
        }
    }

    /// Lets the status item show the menu itself, so it's anchored and highlighted like
    /// any menu-bar menu. The menu is attached only for this click; left clicks keep
    /// opening Settings directly.
    private func showContextMenu() {
        item.menu = contextMenu
        item.button?.performClick(nil)
        item.menu = nil
    }

    @objc private func openSettings() {
        onOpenSettings()
    }

    private static let idleImage: NSImage = {
        let image = NSImage(systemSymbolName: "keyboard", accessibilityDescription: "macatat")!
        image.isTemplate = true
        return image
    }()

    private static let typingImage: NSImage = {
        let green = NSImage.SymbolConfiguration(paletteColors: [.systemGreen])
        let image = NSImage(systemSymbolName: "keyboard.fill", accessibilityDescription: "macatat (typing)")!
            .withSymbolConfiguration(green)!
        image.isTemplate = false
        return image
    }()
}

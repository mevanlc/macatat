import AppKit

/// The menu-bar icon: theme-colored when idle, green while typing.
@MainActor
final class StatusItemController: NSObject {
    private let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private let onClick: @MainActor () -> Void

    var isTyping = false {
        didSet { item.button?.image = isTyping ? Self.typingImage : Self.idleImage }
    }

    var toolTip: String? {
        get { item.button?.toolTip }
        set { item.button?.toolTip = newValue }
    }

    init(onClick: @escaping @MainActor () -> Void) {
        self.onClick = onClick
        super.init()
        item.button?.image = Self.idleImage
        item.button?.target = self
        item.button?.action = #selector(clicked)
    }

    @objc private func clicked() {
        onClick()
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

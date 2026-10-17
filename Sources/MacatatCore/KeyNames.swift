import Carbon.HIToolbox

/// Human-readable names for shortcuts, e.g. "⌃⌥⌘T".
public enum KeyNames {
    @MainActor
    public static func describe(_ combo: HotKeyCombo) -> String {
        modifierSymbols(combo.carbonModifiers) + keyName(for: combo.keyCode)
    }

    /// Symbols in Apple's canonical order: ⌃⌥⇧⌘.
    public static func modifierSymbols(_ carbonModifiers: UInt32) -> String {
        let symbols: [(Int, String)] = [(controlKey, "⌃"), (optionKey, "⌥"), (shiftKey, "⇧"), (cmdKey, "⌘")]
        return symbols.filter { carbonModifiers & UInt32($0.0) != 0 }.map(\.1).joined()
    }

    /// The key's label on the current layout.
    @MainActor
    static func keyName(for keyCode: UInt32) -> String {
        if let name = specialKeyNames[Int(keyCode)] {
            return name
        }
        guard let printed = UnicodeKeyLayout.current()?.translate(UInt16(keyCode), modifiers: 0),
            !printed.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else { return "Key \(keyCode)" }
        let isKeypad = KeyboardLayoutMap.keypadKeyCodes.contains(CGKeyCode(keyCode))
        return (isKeypad ? "Keypad " : "") + printed.uppercased()
    }

    private static let specialKeyNames: [Int: String] = {
        var names = [
            kVK_Return: "↩", kVK_Tab: "⇥", kVK_Space: "Space", kVK_Delete: "⌫", kVK_Escape: "⎋",
            kVK_ForwardDelete: "⌦", kVK_Home: "↖", kVK_End: "↘", kVK_PageUp: "⇞", kVK_PageDown: "⇟",
            kVK_LeftArrow: "←", kVK_RightArrow: "→", kVK_UpArrow: "↑", kVK_DownArrow: "↓",
            kVK_Help: "Help", kVK_ANSI_KeypadEnter: "⌤", kVK_ANSI_KeypadClear: "⌧",
        ]
        let functionKeys = [
            kVK_F1, kVK_F2, kVK_F3, kVK_F4, kVK_F5, kVK_F6, kVK_F7, kVK_F8, kVK_F9, kVK_F10,
            kVK_F11, kVK_F12, kVK_F13, kVK_F14, kVK_F15, kVK_F16, kVK_F17, kVK_F18, kVK_F19, kVK_F20,
        ]
        for (index, keyCode) in functionKeys.enumerated() {
            names[keyCode] = "F\(index + 1)"
        }
        return names
    }()
}

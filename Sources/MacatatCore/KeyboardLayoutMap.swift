import Carbon.HIToolbox
import CoreGraphics
import Foundation

/// Which key press types each character on a keyboard layout.
public struct KeyboardLayoutMap: Sendable {
    public let strokes: [Character: KeyStroke]

    public init(strokes: [Character: KeyStroke]) {
        self.strokes = strokes
    }

    public subscript(character: Character) -> KeyStroke? {
        strokes[character]
    }

    /// The map for the active keyboard layout.
    @MainActor
    public static func current() -> KeyboardLayoutMap? {
        UnicodeKeyLayout.current().map(KeyboardLayoutMap.init(layout:))
    }

    @MainActor
    public init?(inputSource: TISInputSource) {
        guard let layout = UnicodeKeyLayout(inputSource: inputSource) else { return nil }
        self.init(layout: layout)
    }

    /// The installed input source with the given ID, e.g. `com.apple.keylayout.US`.
    @MainActor
    public static func inputSource(id: String) -> TISInputSource? {
        let filter = [kTISPropertyInputSourceID as String: id] as CFDictionary
        guard let list = TISCreateInputSourceList(filter, true)?.takeRetainedValue() else { return nil }
        return (list as? [TISInputSource])?.first
    }

    /// Keeps the simplest stroke for each character: main keys before keypad keys, and
    /// fewer modifiers before more.
    init(layout: UnicodeKeyLayout) {
        var strokes: [Character: KeyStroke] = [:]
        for keyCodes in [Self.mainKeyCodes, Self.keypadKeyCodes] {
            for (carbonModifiers, flags) in Self.modifierCombinations {
                for keyCode in keyCodes {
                    guard let text = layout.translate(keyCode, modifiers: carbonModifiers),
                        let character = Self.typeableCharacter(text),
                        strokes[character] == nil
                    else { continue }
                    strokes[character] = KeyStroke(keyCode: keyCode, flags: flags)
                }
            }
        }
        self.strokes = strokes
    }

    static let keypadKeyCodes: [CGKeyCode] = [
        kVK_ANSI_KeypadDecimal, kVK_ANSI_KeypadMultiply, kVK_ANSI_KeypadPlus, kVK_ANSI_KeypadClear,
        kVK_ANSI_KeypadDivide, kVK_ANSI_KeypadEnter, kVK_ANSI_KeypadMinus, kVK_ANSI_KeypadEquals,
        kVK_ANSI_Keypad0, kVK_ANSI_Keypad1, kVK_ANSI_Keypad2, kVK_ANSI_Keypad3, kVK_ANSI_Keypad4,
        kVK_ANSI_Keypad5, kVK_ANSI_Keypad6, kVK_ANSI_Keypad7, kVK_ANSI_Keypad8, kVK_ANSI_Keypad9,
    ].map { CGKeyCode($0) }

    private static let mainKeyCodes: [CGKeyCode] = (0..<128).map { CGKeyCode($0) }
        .filter { !keypadKeyCodes.contains($0) }

    private static let modifierCombinations: [(carbon: UInt32, flags: CGEventFlags)] = [
        (0, []),
        (UInt32(shiftKey), .maskShift),
        (UInt32(optionKey), .maskAlternate),
        (UInt32(shiftKey | optionKey), [.maskShift, .maskAlternate]),
    ]

    /// `text` as a single visible character, or nil for control, private-use (function
    /// keys) and multi-character output.
    private static func typeableCharacter(_ text: String) -> Character? {
        let text = text.precomposedStringWithCanonicalMapping
        guard text.count == 1, let character = text.first else { return nil }
        let isVisible = character.unicodeScalars.allSatisfy { scalar in
            switch scalar.properties.generalCategory {
            case .control, .format, .privateUse, .surrogate, .unassigned: false
            default: true
            }
        }
        return isVisible ? character : nil
    }
}

import CoreGraphics
import Foundation

/// What to do with a character the keyboard layout has no key press for.
public enum ExtendedCharPolicy: String, CaseIterable, Sendable {
    /// Attach the character itself to a synthetic key event.
    case unicode
    /// Type its closest ASCII spelling instead, dropping it when there is none.
    case transliterate
    /// Drop it.
    case skip
    /// Type nothing at all when the text contains any such character.
    case refuse
}

public enum TypingStep: Equatable, Sendable {
    /// Press a key. `text` is the character the press stands for, when it stands for one.
    case key(KeyStroke, text: String?)
    /// Inject text that no key on the layout produces.
    case unicode(String)
}

/// The key presses that type a piece of text on a given keyboard layout.
public struct TypingPlan: Equatable, Sendable {
    public private(set) var steps: [TypingStep] = []
    /// Characters the layout can't type. Only collected under ``ExtendedCharPolicy/refuse``.
    public private(set) var untypeable: [Character] = []

    public init(
        text: String, layout: KeyboardLayoutMap, newlineFlags: CGEventFlags, policy: ExtendedCharPolicy
    ) {
        // "\r\n" is a single Character, so CRLF line endings become one newline.
        for character in text.precomposedStringWithCanonicalMapping {
            if character.isNewline {
                steps.append(.key(.newline(flags: newlineFlags), text: nil))
            } else if character == "\t" {
                steps.append(.key(.tab, text: nil))
            } else if character.isControl {
                continue
            } else if let stroke = layout[character] {
                steps.append(.key(stroke, text: String(character)))
            } else {
                appendExtended(character, layout: layout, policy: policy)
            }
        }
    }

    private mutating func appendExtended(
        _ character: Character, layout: KeyboardLayoutMap, policy: ExtendedCharPolicy
    ) {
        switch policy {
        case .unicode:
            steps.append(.unicode(String(character)))
        case .transliterate:
            for replacement in Self.asciiTransliteration(of: character) {
                if let stroke = layout[replacement] {
                    steps.append(.key(stroke, text: String(replacement)))
                }
            }
        case .skip:
            break
        case .refuse:
            untypeable.append(character)
        }
    }

    static func asciiTransliteration(of character: Character) -> String {
        String(character).applyingTransform(StringTransform("Any-Latin; Latin-ASCII"), reverse: false) ?? ""
    }
}

extension Character {
    fileprivate var isControl: Bool {
        unicodeScalars.allSatisfy { $0.properties.generalCategory == .control }
    }
}

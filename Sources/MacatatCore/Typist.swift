import Carbon.HIToolbox
import CoreGraphics
import Foundation

public struct TypingOptions: Sendable {
    /// Pause after each key-up, before the next key-down.
    public var interKeyDelay: Duration
    /// How long each key is held down.
    public var keyUpDelay: Duration

    public init(interKeyDelay: Duration, keyUpDelay: Duration) {
        self.interKeyDelay = interKeyDelay
        self.keyUpDelay = keyUpDelay
    }
}

public enum TypistError: Error {
    case eventSourceUnavailable
}

/// Posts synthetic keyboard events. Requires the Accessibility permission.
public enum Typist {
    /// Waits until no Control, Option, Command or Shift key is physically held, so the
    /// modifiers of the shortcut that started typing can't combine with typed keys.
    public static func waitForModifierRelease() async throws {
        let modifiers: CGEventFlags = [.maskShift, .maskControl, .maskAlternate, .maskCommand]
        while !CGEventSource.flagsState(.combinedSessionState).isDisjoint(with: modifiers) {
            try await Task.sleep(for: .milliseconds(10))
        }
    }

    /// Types `steps`. Stops promptly when the task is cancelled, releasing any key it
    /// pressed first.
    public static func type(_ steps: [TypingStep], options: TypingOptions) async throws {
        guard let source = CGEventSource(stateID: .hidSystemState) else {
            throw TypistError.eventSourceUnavailable
        }
        for step in steps {
            for (stroke, text) in presses(for: step) {
                try Task.checkCancellation()
                try await press(stroke, text: text, source: source, options: options)
                try await pause(options.interKeyDelay)
            }
        }
    }

    private static func presses(for step: TypingStep) -> [(KeyStroke, [UniChar]?)] {
        switch step {
        case let .key(stroke, text):
            [(stroke, text.map { Array($0.utf16) })]
        case let .unicode(text):
            unicodeChunks(text).map { (KeyStroke(keyCode: 0), $0) }
        }
    }

    /// Presses and releases `stroke`. When `text` is given it rides along on both events,
    /// so apps receive exactly that text whatever the caps-lock state or layout, while
    /// targets that read keycodes (VMs, remote desktops) still see the physical key.
    private static func press(
        _ stroke: KeyStroke, text: [UniChar]?, source: CGEventSource, options: TypingOptions
    ) async throws {
        // Hold the modifier keys themselves, not just their flags: targets that track
        // modifier key state (VMs, remote desktops) ignore flags on the key event.
        let modifiers = modifierStrokes(for: stroke.flags)
        for modifier in modifiers {
            post(modifier, text: nil, keyDown: true, source: source)
        }
        defer {
            for index in modifiers.indices.reversed() {
                let remaining = index > 0 ? modifiers[index - 1].flags : []
                let release = KeyStroke(keyCode: modifiers[index].keyCode, flags: remaining)
                post(release, text: nil, keyDown: false, source: source)
            }
        }
        post(stroke, text: text, keyDown: true, source: source)
        defer { post(stroke, text: text, keyDown: false, source: source) }
        try await pause(options.keyUpDelay)
    }

    /// The modifier keys `flags` calls for, in press order, each carrying the flags in
    /// effect once it is down.
    static func modifierStrokes(for flags: CGEventFlags) -> [KeyStroke] {
        var held: CGEventFlags = []
        return modifierKeys.compactMap { keyCode, flag in
            guard flags.contains(flag) else { return nil }
            held.insert(flag)
            return KeyStroke(keyCode: keyCode, flags: held)
        }
    }

    private static let modifierKeys: [(keyCode: CGKeyCode, flag: CGEventFlags)] = [
        (CGKeyCode(kVK_Control), .maskControl),
        (CGKeyCode(kVK_Option), .maskAlternate),
        (CGKeyCode(kVK_Shift), .maskShift),
        (CGKeyCode(kVK_Command), .maskCommand),
    ]

    private static func post(_ stroke: KeyStroke, text: [UniChar]?, keyDown: Bool, source: CGEventSource) {
        guard let event = CGEvent(keyboardEventSource: source, virtualKey: stroke.keyCode, keyDown: keyDown)
        else { return }
        // Assigning the flags outright keeps held modifiers and caps lock out of the event.
        event.flags = stroke.flags
        if let text {
            event.keyboardSetUnicodeString(stringLength: text.count, unicodeString: text)
        }
        event.post(tap: .cghidEventTap)
    }

    private static func pause(_ duration: Duration) async throws {
        if duration > .zero {
            try await Task.sleep(for: duration)
        } else {
            try Task.checkCancellation()
        }
    }

    /// The longest string a single CGEvent carries.
    static let maxEventTextLength = 20

    /// Splits `text` into pieces of at most ``maxEventTextLength`` UTF-16 units without
    /// splitting a surrogate pair.
    static func unicodeChunks(_ text: String) -> [[UniChar]] {
        var chunks: [[UniChar]] = []
        var chunk: [UniChar] = []
        for scalar in text.unicodeScalars {
            let units = Array(scalar.utf16)
            if chunk.count + units.count > maxEventTextLength {
                chunks.append(chunk)
                chunk = []
            }
            chunk += units
        }
        if !chunk.isEmpty {
            chunks.append(chunk)
        }
        return chunks
    }
}

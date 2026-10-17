import Carbon.HIToolbox
import CoreGraphics

/// A physical key press: a virtual keycode plus the modifier flags held with it.
public struct KeyStroke: Equatable, Sendable {
    public var keyCode: CGKeyCode
    public var flags: CGEventFlags

    public init(keyCode: CGKeyCode, flags: CGEventFlags = []) {
        self.keyCode = keyCode
        self.flags = flags
    }

    public static let tab = KeyStroke(keyCode: CGKeyCode(kVK_Tab))

    public static func newline(flags: CGEventFlags) -> KeyStroke {
        KeyStroke(keyCode: CGKeyCode(kVK_Return), flags: flags)
    }
}

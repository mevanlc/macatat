import Carbon.HIToolbox

/// A global shortcut in the form Carbon's `RegisterEventHotKey` takes.
public struct HotKeyCombo: Equatable, Sendable {
    public var keyCode: UInt32
    /// `controlKey | optionKey | shiftKey | cmdKey` bits.
    public var carbonModifiers: UInt32

    public init(keyCode: UInt32, carbonModifiers: UInt32) {
        self.keyCode = keyCode
        self.carbonModifiers = carbonModifiers
    }

    /// ⌃⌥⌘T
    public static let `default` = HotKeyCombo(
        keyCode: UInt32(kVK_ANSI_T), carbonModifiers: UInt32(controlKey | optionKey | cmdKey))
}

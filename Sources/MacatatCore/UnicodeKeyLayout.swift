import Carbon.HIToolbox
import Foundation

/// A keyboard layout's `uchr` data, used to ask which text a keycode types.
struct UnicodeKeyLayout {
    private let layoutData: Data
    private let keyboardType: UInt32

    @MainActor
    init?(inputSource: TISInputSource) {
        guard let property = TISGetInputSourceProperty(inputSource, kTISPropertyUnicodeKeyLayoutData) else {
            return nil
        }
        layoutData = Unmanaged<CFData>.fromOpaque(property).takeUnretainedValue() as Data
        keyboardType = UInt32(LMGetKbdType())
    }

    /// The current keyboard layout, or the current ASCII-capable one when the current
    /// input source (e.g. an input method) carries no layout data.
    @MainActor
    static func current() -> UnicodeKeyLayout? {
        let sources = [
            TISCopyCurrentKeyboardLayoutInputSource(),
            TISCopyCurrentASCIICapableKeyboardLayoutInputSource(),
        ].compactMap { $0?.takeRetainedValue() }
        return sources.lazy.compactMap(UnicodeKeyLayout.init(inputSource:)).first
    }

    /// The text `keyCode` types with the Carbon `modifiers` held, or nil when it types
    /// nothing or is a dead key (one that only modifies the next key press).
    func translate(_ keyCode: UInt16, modifiers: UInt32) -> String? {
        layoutData.withUnsafeBytes { buffer -> String? in
            guard let layout = buffer.baseAddress?.assumingMemoryBound(to: UCKeyboardLayout.self) else {
                return nil
            }
            var deadKeyState: UInt32 = 0
            var length = 0
            var chars = [UniChar](repeating: 0, count: 8)
            let status = UCKeyTranslate(
                layout, keyCode, UInt16(kUCKeyActionDown), (modifiers >> 8) & 0xFF, keyboardType,
                OptionBits(0), &deadKeyState, chars.count, &length, &chars)
            guard status == noErr, deadKeyState == 0, length > 0 else { return nil }
            return String(utf16CodeUnits: chars, count: length)
        }
    }
}

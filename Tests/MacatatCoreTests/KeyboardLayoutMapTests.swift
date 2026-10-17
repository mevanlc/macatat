import Carbon.HIToolbox
import Testing

@testable import MacatatCore

@MainActor
struct KeyboardLayoutMapTests {
    let map: KeyboardLayoutMap

    init() throws {
        let source = try #require(KeyboardLayoutMap.inputSource(id: "com.apple.keylayout.US"))
        map = try #require(KeyboardLayoutMap(inputSource: source))
    }

    @Test func lowercaseLetterNeedsNoModifiers() {
        #expect(map["a"] == KeyStroke(keyCode: CGKeyCode(kVK_ANSI_A)))
    }

    @Test func uppercaseLetterUsesShift() {
        #expect(map["A"] == KeyStroke(keyCode: CGKeyCode(kVK_ANSI_A), flags: .maskShift))
    }

    @Test func digitsPreferTheMainRowOverTheKeypad() {
        #expect(map["1"] == KeyStroke(keyCode: CGKeyCode(kVK_ANSI_1)))
        #expect(map["*"] == KeyStroke(keyCode: CGKeyCode(kVK_ANSI_8), flags: .maskShift))
    }

    @Test func shiftedSymbols() {
        #expect(map["!"] == KeyStroke(keyCode: CGKeyCode(kVK_ANSI_1), flags: .maskShift))
        #expect(map["?"] == KeyStroke(keyCode: CGKeyCode(kVK_ANSI_Slash), flags: .maskShift))
    }

    @Test func optionSymbols() {
        #expect(map["¡"] == KeyStroke(keyCode: CGKeyCode(kVK_ANSI_1), flags: .maskAlternate))
    }

    @Test func space() {
        #expect(map[" "] == KeyStroke(keyCode: CGKeyCode(kVK_Space)))
    }

    @Test func deadKeysAreNotMapped() {
        // Option-E starts an acute-accent sequence on the U.S. layout.
        let optionE = KeyStroke(keyCode: CGKeyCode(kVK_ANSI_E), flags: .maskAlternate)
        #expect(!map.strokes.values.contains(optionE))
        #expect(map["é"] == nil)
    }

    @Test func controlCharactersAreNotMapped() {
        #expect(map["\r"] == nil)
        #expect(map["\t"] == nil)
        #expect(map["\u{1B}"] == nil)
    }
}

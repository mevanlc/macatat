import Carbon.HIToolbox
import CoreGraphics
import Testing

@testable import MacatatCore

struct TypingPlanTests {
    static let a = KeyStroke(keyCode: 0)
    static let e = KeyStroke(keyCode: 14)
    static let quote = KeyStroke(keyCode: 39, flags: .maskShift)
    static let dash = KeyStroke(keyCode: 27)
    static let layout = KeyboardLayoutMap(strokes: ["a": a, "e": e, "\"": quote, "-": dash])

    static func plan(_ text: String, newlineFlags: CGEventFlags = [], policy: ExtendedCharPolicy = .unicode)
        -> TypingPlan
    {
        TypingPlan(text: text, layout: layout, newlineFlags: newlineFlags, policy: policy)
    }

    @Test func mappedCharactersCarryTheirText() {
        #expect(Self.plan("ae").steps == [.key(Self.a, text: "a"), .key(Self.e, text: "e")])
    }

    @Test(arguments: ["\n", "\r", "\r\n", "\u{2028}"])
    func eachLineBreakIsOneReturn(lineBreak: String) {
        #expect(Self.plan("a\(lineBreak)a").steps == [
            .key(Self.a, text: "a"), .key(.newline(flags: []), text: nil), .key(Self.a, text: "a"),
        ])
    }

    @Test func newlinesUseTheConfiguredModifiers() {
        let flags: CGEventFlags = [.maskShift, .maskControl]
        #expect(Self.plan("\n", newlineFlags: flags).steps == [.key(.newline(flags: flags), text: nil)])
    }

    @Test func tabIsTheTabKey() {
        #expect(Self.plan("\t").steps == [.key(.tab, text: nil)])
    }

    @Test func otherControlCharactersAreDropped() {
        #expect(Self.plan("a\u{07}\u{00}a").steps == [.key(Self.a, text: "a"), .key(Self.a, text: "a")])
    }

    @Test func decomposedInputIsPrecomposed() {
        // "e" + COMBINING ACUTE ACCENT is one unmapped character, "é".
        #expect(Self.plan("e\u{301}", policy: .unicode).steps == [.unicode("é")])
    }

    @Test func unicodePolicyInjectsTheCharacter() {
        #expect(Self.plan("a😀", policy: .unicode).steps == [.key(Self.a, text: "a"), .unicode("😀")])
    }

    @Test func transliteratePolicyTypesTheAsciiSpelling() {
        #expect(Self.plan("é“—", policy: .transliterate).steps == [
            .key(Self.e, text: "e"), .key(Self.quote, text: "\""), .key(Self.dash, text: "-"),
        ])
    }

    @Test func transliteratePolicyDropsWhatItCannotSpell() {
        #expect(Self.plan("😀a", policy: .transliterate).steps == [.key(Self.a, text: "a")])
    }

    @Test func skipPolicyDropsTheCharacter() {
        #expect(Self.plan("aé", policy: .skip).steps == [.key(Self.a, text: "a")])
    }

    @Test func refusePolicyCollectsUntypeableCharacters() {
        let plan = Self.plan("aéa😀", policy: .refuse)
        #expect(plan.untypeable == ["é", "😀"])
    }

    @Test func otherPoliciesCollectNothing() {
        for policy in [ExtendedCharPolicy.unicode, .transliterate, .skip] {
            #expect(Self.plan("é", policy: policy).untypeable.isEmpty)
        }
    }
}

struct ModifierStrokeTests {
    @Test func noFlagsNeedNoModifierKeys() {
        #expect(Typist.modifierStrokes(for: []).isEmpty)
    }

    @Test func modifiersPressInCanonicalOrderWithCumulativeFlags() {
        #expect(Typist.modifierStrokes(for: [.maskShift, .maskCommand, .maskControl]) == [
            KeyStroke(keyCode: CGKeyCode(kVK_Control), flags: .maskControl),
            KeyStroke(keyCode: CGKeyCode(kVK_Shift), flags: [.maskControl, .maskShift]),
            KeyStroke(keyCode: CGKeyCode(kVK_Command), flags: [.maskControl, .maskShift, .maskCommand]),
        ])
    }
}

struct UnicodeChunkTests {
    @Test func shortTextIsOneChunk() {
        #expect(Typist.unicodeChunks("😀") == [Array("😀".utf16)])
    }

    @Test func longTextSplitsWithoutBreakingSurrogatePairs() {
        // 11 emoji = 22 UTF-16 units: 10 emoji fit in the first chunk, 1 in the second.
        let text = String(repeating: "😀", count: 11)
        let chunks = Typist.unicodeChunks(text)
        #expect(chunks.map(\.count) == [20, 2])
        #expect(chunks.flatMap { $0 } == Array(text.utf16))
    }
}

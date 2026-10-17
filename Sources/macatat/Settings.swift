import CoreGraphics
import Foundation
import MacatatCore
import Observation

/// User preferences, saved to UserDefaults as they change.
@MainActor
@Observable
final class Settings {
    nonisolated static let delayRange: ClosedRange<Double> = 0...1

    var hotKey: HotKeyCombo {
        didSet {
            defaults.set(Int(hotKey.keyCode), forKey: Key.hotKeyCode)
            defaults.set(Int(hotKey.carbonModifiers), forKey: Key.hotKeyModifiers)
            hotKeyDidChange?()
        }
    }
    var newlineControl: Bool { didSet { defaults.set(newlineControl, forKey: Key.newlineControl) } }
    var newlineOption: Bool { didSet { defaults.set(newlineOption, forKey: Key.newlineOption) } }
    var newlineCommand: Bool { didSet { defaults.set(newlineCommand, forKey: Key.newlineCommand) } }
    var newlineShift: Bool { didSet { defaults.set(newlineShift, forKey: Key.newlineShift) } }
    var extendedPolicy: ExtendedCharPolicy {
        didSet { defaults.set(extendedPolicy.rawValue, forKey: Key.extendedPolicy) }
    }
    /// Seconds.
    var interKeyDelay: Double { didSet { defaults.set(interKeyDelay, forKey: Key.interKeyDelay) } }
    /// Seconds.
    var keyUpDelay: Double { didSet { defaults.set(keyUpDelay, forKey: Key.keyUpDelay) } }

    @ObservationIgnored var hotKeyDidChange: (@MainActor () -> Void)?
    @ObservationIgnored private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        defaults.register(defaults: [
            Key.hotKeyCode: Int(HotKeyCombo.default.keyCode),
            Key.hotKeyModifiers: Int(HotKeyCombo.default.carbonModifiers),
            Key.extendedPolicy: ExtendedCharPolicy.unicode.rawValue,
            Key.interKeyDelay: 0.015,
            Key.keyUpDelay: 0.005,
        ])
        self.defaults = defaults
        hotKey = HotKeyCombo(
            keyCode: UInt32(defaults.integer(forKey: Key.hotKeyCode)),
            carbonModifiers: UInt32(defaults.integer(forKey: Key.hotKeyModifiers)))
        newlineControl = defaults.bool(forKey: Key.newlineControl)
        newlineOption = defaults.bool(forKey: Key.newlineOption)
        newlineCommand = defaults.bool(forKey: Key.newlineCommand)
        newlineShift = defaults.bool(forKey: Key.newlineShift)
        extendedPolicy = defaults.string(forKey: Key.extendedPolicy).flatMap(ExtendedCharPolicy.init) ?? .unicode
        interKeyDelay = defaults.double(forKey: Key.interKeyDelay)
        keyUpDelay = defaults.double(forKey: Key.keyUpDelay)
    }

    var newlineFlags: CGEventFlags {
        var flags: CGEventFlags = []
        if newlineControl { flags.insert(.maskControl) }
        if newlineOption { flags.insert(.maskAlternate) }
        if newlineCommand { flags.insert(.maskCommand) }
        if newlineShift { flags.insert(.maskShift) }
        return flags
    }

    var typingOptions: TypingOptions {
        TypingOptions(interKeyDelay: Self.duration(interKeyDelay), keyUpDelay: Self.duration(keyUpDelay))
    }

    private static func duration(_ seconds: Double) -> Duration {
        .seconds(seconds.clamped(to: delayRange))
    }

    private enum Key {
        static let hotKeyCode = "hotKeyCode"
        static let hotKeyModifiers = "hotKeyModifiers"
        static let newlineControl = "newlineControl"
        static let newlineOption = "newlineOption"
        static let newlineCommand = "newlineCommand"
        static let newlineShift = "newlineShift"
        static let extendedPolicy = "extendedPolicy"
        static let interKeyDelay = "interKeyDelay"
        static let keyUpDelay = "keyUpDelay"
    }
}

extension Double {
    func clamped(to range: ClosedRange<Double>) -> Double {
        Swift.min(Swift.max(self, range.lowerBound), range.upperBound)
    }
}

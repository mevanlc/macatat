import AppKit
import ApplicationServices

/// The Accessibility permission, which posting keyboard events requires.
enum Accessibility {
    static var isTrusted: Bool {
        AXIsProcessTrusted()
    }

    /// Shows macOS's prompt to grant the permission, if it isn't granted yet.
    static func requestTrust() {
        // The value of kAXTrustedCheckOptionPrompt, whose global isn't concurrency-safe.
        _ = AXIsProcessTrustedWithOptions(["AXTrustedCheckOptionPrompt": true] as CFDictionary)
    }

    static func openSystemSettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        NSWorkspace.shared.open(url)
    }
}

import AppKit
import Carbon.HIToolbox
import MacatatCore

/// Wires the menu-bar icon, the global shortcut and the settings window to typing
/// sessions.
@MainActor
final class AppController: NSObject, NSApplicationDelegate {
    private let settings = Settings()
    private let status = AppStatus()
    private var statusItem: StatusItemController?
    private var settingsWindow: SettingsWindowController?
    private var hotKey: GlobalHotKey?
    private var session: Task<Void, Never>?
    private var isRecordingHotKey = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.mainMenu = MainMenu.make()
        statusItem = StatusItemController(onOpenSettings: { [weak self] in self?.showSettings() })
        hotKey = GlobalHotKey { [weak self] in self?.hotKeyPressed() }
        settingsWindow = SettingsWindowController(
            rootView: SettingsView(
                settings: settings,
                status: status,
                onRecordingChange: { [weak self] in self?.setRecordingHotKey($0) },
                onQuit: { NSApp.terminate(nil) }),
            onRefresh: { [weak self] in self?.refreshAccessibility() })
        settings.hotKeyDidChange = { [weak self] in self?.registerHotKey() }
        registerHotKey()

        refreshAccessibility()
        if !status.accessibilityGranted {
            Accessibility.requestTrust()
            showSettings()
        }
    }

    private func showSettings() {
        settingsWindow?.show()
    }

    private func refreshAccessibility() {
        status.accessibilityGranted = Accessibility.isTrusted
    }

    // MARK: Shortcut

    private func registerHotKey() {
        guard !isRecordingHotKey, let hotKey else { return }
        let name = KeyNames.describe(settings.hotKey)
        status.hotKeyError =
            switch hotKey.register(settings.hotKey) {
            case noErr: nil
            case OSStatus(eventHotKeyExistsErr): "\(name) is already in use by another app."
            case let error: "Couldn't register \(name) (error \(error))."
            }
        statusItem?.toolTip = "macatat: \(name) types the clipboard"
    }

    private func setRecordingHotKey(_ recording: Bool) {
        isRecordingHotKey = recording
        if recording {
            hotKey?.unregister()
        } else {
            registerHotKey()
        }
    }

    // MARK: Typing

    private func hotKeyPressed() {
        if let session {
            session.cancel()
        } else {
            startTyping()
        }
    }

    private func startTyping() {
        refreshAccessibility()
        guard status.accessibilityGranted else {
            return fail("Accessibility permission is required", showingSettings: true)
        }
        guard let text = NSPasteboard.general.string(forType: .string), !text.isEmpty else {
            return fail("The clipboard has no text")
        }
        guard let layout = KeyboardLayoutMap.current() else {
            return fail("Couldn't read the keyboard layout")
        }
        let plan = TypingPlan(
            text: text, layout: layout, newlineFlags: settings.newlineFlags, policy: settings.extendedPolicy)
        guard plan.untypeable.isEmpty else {
            let examples = String(plan.untypeable.prefix(5))
            return fail("Refused: \(plan.untypeable.count) untypeable characters (e.g. \(examples))")
        }

        let steps = plan.steps
        let options = settings.typingOptions
        status.message = "Typing \(steps.count) characters…"
        statusItem?.isTyping = true
        session = Task.detached(priority: .userInitiated) { [weak self] in
            let outcome: String
            do {
                try await Typist.waitForModifierRelease()
                try await Typist.type(steps, options: options)
                outcome = "Typed \(steps.count) characters"
            } catch is CancellationError {
                outcome = "Stopped"
            } catch {
                outcome = "Typing failed: \(error)"
            }
            await self?.sessionEnded(outcome)
        }
    }

    private func sessionEnded(_ outcome: String) {
        session = nil
        statusItem?.isTyping = false
        status.message = outcome
    }

    private func fail(_ message: String, showingSettings: Bool = false) {
        NSSound.beep()
        status.message = message
        if showingSettings {
            showSettings()
        }
    }
}

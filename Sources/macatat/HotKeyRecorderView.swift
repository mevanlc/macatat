import AppKit
import Carbon.HIToolbox
import Combine
import MacatatCore
import SwiftUI

/// A button showing a shortcut. Clicking it records the next key combination typed;
/// Esc cancels.
struct HotKeyRecorderView: View {
    @Binding var combo: HotKeyCombo
    /// Told when recording starts and stops, so the live shortcut can be suspended
    /// (otherwise pressing it would type instead of being recorded).
    let onRecordingChange: @MainActor (Bool) -> Void
    @State private var monitor: Any?

    private var isRecording: Bool { monitor != nil }

    var body: some View {
        Button(action: toggleRecording) {
            Text(isRecording ? "Type shortcut…" : KeyNames.describe(combo))
                .frame(minWidth: 110)
        }
        .onDisappear(perform: stopRecording)
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.willCloseNotification)) { _ in
            stopRecording()
        }
    }

    private func toggleRecording() {
        isRecording ? stopRecording() : startRecording()
    }

    private func startRecording() {
        onRecordingChange(true)
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            record(event)
            return nil
        }
    }

    private func stopRecording() {
        guard let monitor else { return }
        NSEvent.removeMonitor(monitor)
        self.monitor = nil
        onRecordingChange(false)
    }

    private func record(_ event: NSEvent) {
        let modifiers = event.modifierFlags.intersection([.control, .option, .shift, .command])
        if event.keyCode == UInt16(kVK_Escape), modifiers.isEmpty {
            stopRecording()
            return
        }
        // Shift alone would collide with ordinary typing.
        guard !modifiers.isDisjoint(with: [.control, .option, .command]) else {
            NSSound.beep()
            return
        }
        combo = HotKeyCombo(keyCode: UInt32(event.keyCode), carbonModifiers: modifiers.carbonModifiers)
        stopRecording()
    }
}

extension NSEvent.ModifierFlags {
    fileprivate var carbonModifiers: UInt32 {
        let pairs: [(NSEvent.ModifierFlags, Int)] = [
            (.control, controlKey), (.option, optionKey), (.shift, shiftKey), (.command, cmdKey),
        ]
        return pairs.filter { contains($0.0) }.reduce(0) { $0 | UInt32($1.1) }
    }
}

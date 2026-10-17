import MacatatCore
import SwiftUI

struct SettingsView: View {
    @Bindable var settings: Settings
    let status: AppStatus
    let onRecordingChange: @MainActor (Bool) -> Void
    let onQuit: @MainActor () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Form {
                Section {
                    LabeledContent("Accessibility") { accessibilityState }
                    LabeledContent("Status") {
                        Text(status.message).foregroundStyle(.secondary)
                    }
                }

                Section {
                    LabeledContent("Type clipboard") {
                        HStack {
                            HotKeyRecorderView(combo: $settings.hotKey, onRecordingChange: onRecordingChange)
                            Button("Reset") { settings.hotKey = .default }
                                .disabled(settings.hotKey == .default)
                        }
                    }
                    if let error = status.hotKeyError {
                        Text(error).foregroundStyle(.red)
                    }
                } footer: {
                    Text("Press the shortcut again while typing to stop.")
                        .foregroundStyle(.secondary)
                }

                Section {
                    LabeledContent("Send newlines with") {
                        HStack {
                            Toggle("⌃ Ctrl", isOn: $settings.newlineControl)
                            Toggle("⌥ Opt", isOn: $settings.newlineOption)
                            Toggle("⌘ Cmd", isOn: $settings.newlineCommand)
                            Toggle("⇧ Shift", isOn: $settings.newlineShift)
                        }
                        .toggleStyle(.checkbox)
                    }
                    Picker("Extended characters", selection: $settings.extendedPolicy) {
                        ForEach(ExtendedCharPolicy.allCases, id: \.self) { policy in
                            Text(policy.title).tag(policy)
                        }
                    }
                    DelayField(title: "Inter-key delay (s)", value: $settings.interKeyDelay)
                    DelayField(title: "Key-up delay (s)", value: $settings.keyUpDelay)
                } footer: {
                    Text(settings.extendedPolicy.explanation)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .formStyle(.grouped)
            .scrollDisabled(true)

            HStack {
                Spacer()
                Button("Quit macatat", action: onQuit)
            }
            .padding([.horizontal, .bottom], 20)
        }
        .frame(width: 520)
        .fixedSize(horizontal: false, vertical: true)
    }

    @ViewBuilder
    private var accessibilityState: some View {
        if status.accessibilityGranted {
            Label("Granted", systemImage: "checkmark.circle.fill")
                .foregroundStyle(.green)
        } else {
            HStack {
                Label("Not granted", systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                Button("Open Settings…", action: Accessibility.openSystemSettings)
            }
        }
    }
}

/// A seconds value edited as text or stepped by a millisecond.
private struct DelayField: View {
    let title: String
    @Binding var value: Double

    var body: some View {
        let clamped = Binding(
            get: { value },
            set: { value = $0.clamped(to: Settings.delayRange) })
        LabeledContent(title) {
            HStack(spacing: 4) {
                TextField(title, value: clamped, format: .number.precision(.fractionLength(3)))
                    .labelsHidden()
                    .multilineTextAlignment(.trailing)
                    .frame(width: 64)
                Stepper(title, value: clamped, in: Settings.delayRange, step: 0.001)
                    .labelsHidden()
            }
        }
    }
}

extension ExtendedCharPolicy {
    fileprivate var title: String {
        switch self {
        case .unicode: "Unicode-inject"
        case .transliterate: "Transliterate to ASCII"
        case .skip: "Skip"
        case .refuse: "Refuse to type"
        }
    }

    fileprivate var explanation: String {
        let subject = "Characters your keyboard layout can't type"
        return switch self {
        case .unicode:
            "\(subject) are sent as Unicode text attached to a key event. This works in most Mac apps, "
                + "but usually not in VMs or remote desktops."
        case .transliterate:
            "\(subject) are replaced with their closest ASCII spelling (é → e, “ → \", — → -). "
                + "Those with none are dropped."
        case .skip:
            "\(subject) are dropped."
        case .refuse:
            "If the clipboard contains any characters your keyboard layout can't type, nothing is typed."
        }
    }
}

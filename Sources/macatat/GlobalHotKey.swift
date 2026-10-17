import Carbon.HIToolbox
import MacatatCore

/// A system-wide shortcut registered with Carbon, which needs no extra permission.
@MainActor
final class GlobalHotKey {
    private let action: @MainActor () -> Void
    private var hotKeyRef: EventHotKeyRef?
    private var handlerRef: EventHandlerRef?

    init(action: @escaping @MainActor () -> Void) {
        self.action = action
        var pressed = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(
            GetApplicationEventTarget(),
            { _, _, userData in
                guard let userData else { return OSStatus(eventNotHandledErr) }
                let hotKey = Unmanaged<GlobalHotKey>.fromOpaque(userData).takeUnretainedValue()
                // Carbon dispatches application events on the main thread.
                MainActor.assumeIsolated { hotKey.action() }
                return noErr
            },
            1, &pressed, Unmanaged.passUnretained(self).toOpaque(), &handlerRef)
    }

    /// Replaces any registered shortcut with `combo`. Returns `eventHotKeyExistsErr` when
    /// another app already owns it.
    func register(_ combo: HotKeyCombo) -> OSStatus {
        unregister()
        let id = EventHotKeyID(signature: OSType(0x6D_63_74_74), id: 1)  // 'mctt'
        var ref: EventHotKeyRef?
        let status = RegisterEventHotKey(
            combo.keyCode, combo.carbonModifiers, id, GetApplicationEventTarget(), 0, &ref)
        if status == noErr {
            hotKeyRef = ref
        }
        return status
    }

    func unregister() {
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
            self.hotKeyRef = nil
        }
    }
}

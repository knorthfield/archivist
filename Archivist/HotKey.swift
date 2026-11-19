import AppKit
import Carbon.HIToolbox

/// The global shortcut ⇧⌘V. A Carbon hot key needs no permission, and the app at the front
/// does not get the key.
@MainActor
enum HotKey {
    private static var action: (() -> Void)?

    static func register(action: @escaping () -> Void) {
        self.action = action
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, _, _ in
            // Carbon calls the handler on the main thread.
            MainActor.assumeIsolated { HotKey.action?() }
            return noErr
        }, 1, &eventType, nil, nil)
        var hotKey: EventHotKeyRef?
        let id = EventHotKeyID(signature: OSType(0x4152_4348), id: 1)
        RegisterEventHotKey(UInt32(Paster.currentVKey), UInt32(cmdKey | shiftKey), id,
                            GetApplicationEventTarget(), 0, &hotKey)
    }
}

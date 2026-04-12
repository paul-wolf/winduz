import AppKit
import Carbon.HIToolbox

final class GlobalHotKey {
    private var hotKeyRef: EventHotKeyRef?
    private var eventHandlerRef: EventHandlerRef?
    private let handler: () -> Void

    init(keyCode: UInt32, modifiers: UInt32, handler: @escaping () -> Void) {
        self.handler = handler

        let id = EventHotKeyID(signature: fourCharCode("WNDZ"), id: 1)
        RegisterEventHotKey(keyCode, modifiers, id, GetApplicationEventTarget(), 0, &hotKeyRef)

        var type = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        let selfPtr = Unmanaged.passUnretained(self).toOpaque()
        InstallEventHandler(
            GetApplicationEventTarget(),
            { _, _, userData -> OSStatus in
                guard let userData else { return noErr }
                Unmanaged<GlobalHotKey>.fromOpaque(userData).takeUnretainedValue().handler()
                return noErr
            },
            1, &type, selfPtr, &eventHandlerRef
        )
    }

    deinit {
        if let h = eventHandlerRef { RemoveEventHandler(h) }
        if let k = hotKeyRef { UnregisterEventHotKey(k) }
    }
}

private func fourCharCode(_ s: String) -> FourCharCode {
    precondition(s.utf8.count == 4)
    var result: FourCharCode = 0
    for b in s.utf8 { result = (result << 8) | FourCharCode(b) }
    return result
}

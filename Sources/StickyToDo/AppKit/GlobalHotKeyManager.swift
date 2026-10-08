import Carbon
import Foundation

private let quickAddHotKeySignature: OSType = 0x5354444F // "STDO"
private let quickAddHotKeyID: UInt32 = 1

private func stickyToDoGlobalHotKeyHandler(
    _ nextHandler: EventHandlerCallRef?,
    _ event: EventRef?,
    _ userData: UnsafeMutableRawPointer?
) -> OSStatus {
    guard let userData, let event else { return OSStatus(eventNotHandledErr) }
    let manager = Unmanaged<GlobalHotKeyManager>.fromOpaque(userData).takeUnretainedValue()

    var hotKeyID = EventHotKeyID()
    let status = GetEventParameter(
        event,
        EventParamName(kEventParamDirectObject),
        EventParamType(typeEventHotKeyID),
        nil,
        MemoryLayout<EventHotKeyID>.size,
        nil,
        &hotKeyID
    )
    guard status == noErr else { return status }

    if hotKeyID.signature == quickAddHotKeySignature && hotKeyID.id == quickAddHotKeyID {
        manager.handleTriggered()
        return noErr
    }
    return OSStatus(eventNotHandledErr)
}

/// Wraps the Carbon global hotkey APIs used to trigger quick-add (⌥⌘N)
/// from anywhere on the system, independent of window/app focus.
final class GlobalHotKeyManager {
    static let quickAddShortcutDisplay = "⌥⌘N"

    var onTriggered: (() -> Void)?
    private var hotKeyRef: EventHotKeyRef?
    private var hotKeyHandlerRef: EventHandlerRef?

    deinit {
        unregister()
    }

    @discardableResult
    func register() -> Bool {
        unregister()

        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: OSType(kEventHotKeyPressed)
        )

        let userData = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
        let installStatus = InstallEventHandler(
            GetEventDispatcherTarget(),
            stickyToDoGlobalHotKeyHandler,
            1,
            &eventType,
            userData,
            &hotKeyHandlerRef
        )
        guard installStatus == noErr else { return false }

        let hotKeyID = EventHotKeyID(signature: quickAddHotKeySignature, id: quickAddHotKeyID)
        let modifierFlags = UInt32(cmdKey | optionKey)
        let registerStatus = RegisterEventHotKey(
            UInt32(kVK_ANSI_N),
            modifierFlags,
            hotKeyID,
            GetEventDispatcherTarget(),
            0,
            &hotKeyRef
        )
        guard registerStatus == noErr else {
            unregister()
            return false
        }
        return true
    }

    func unregister() {
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
            self.hotKeyRef = nil
        }
        if let hotKeyHandlerRef {
            RemoveEventHandler(hotKeyHandlerRef)
            self.hotKeyHandlerRef = nil
        }
    }

    fileprivate func handleTriggered() {
        onTriggered?()
    }
}

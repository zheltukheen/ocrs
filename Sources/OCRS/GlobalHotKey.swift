import Carbon
import AppKit

final class GlobalHotKey {
    private var hotKeyRef: EventHotKeyRef?
    private var eventHandler: EventHandlerRef?
    fileprivate var hotKeyID: EventHotKeyID
    private let callback: () -> Void

    private static var uniqueID: UInt32 = 1

    init(keyCode: Int, modifiers: UInt, callback: @escaping () -> Void) {
        self.callback = callback
        self.hotKeyID = EventHotKeyID(signature: 0x4F435253, id: Self.uniqueID) // 'OCRS'
        Self.uniqueID += 1

        registerHotKey(keyCode: keyCode, modifiers: modifiers)
    }

    deinit {
        unregister()
    }

    private func registerHotKey(keyCode: Int, modifiers: UInt) {
        var carbonModifiers: UInt32 = 0
        if modifiers & NSEvent.ModifierFlags.command.rawValue != 0 { carbonModifiers |= UInt32(cmdKey) }
        if modifiers & NSEvent.ModifierFlags.option.rawValue != 0 { carbonModifiers |= UInt32(optionKey) }
        if modifiers & NSEvent.ModifierFlags.control.rawValue != 0 { carbonModifiers |= UInt32(controlKey) }
        if modifiers & NSEvent.ModifierFlags.shift.rawValue != 0 { carbonModifiers |= UInt32(shiftKey) }

        let status = RegisterEventHotKey(UInt32(keyCode), carbonModifiers, hotKeyID, GetApplicationEventTarget(), 0, &hotKeyRef)
        guard status == noErr else { return }

        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let selfPointer = Unmanaged.passUnretained(self).toOpaque()
        InstallEventHandler(GetApplicationEventTarget(), GlobalHotKeyHandler, 1, &spec, selfPointer, &eventHandler)
    }

    private func unregister() {
        if let ref = hotKeyRef { UnregisterEventHotKey(ref) }
        if let handler = eventHandler { RemoveEventHandler(handler) }
        hotKeyRef = nil
        eventHandler = nil
    }

    fileprivate func handleEvent() {
        callback()
    }
}

private func GlobalHotKeyHandler(handler: EventHandlerCallRef?, event: EventRef?, userData: UnsafeMutableRawPointer?) -> OSStatus {
    guard let userData else { return OSStatus(noErr) }
    let instance = Unmanaged<GlobalHotKey>.fromOpaque(userData).takeUnretainedValue()

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

    if status == noErr, hotKeyID.id == instance.hotKeyID.id {
        instance.handleEvent()
    }

    return OSStatus(noErr)
}

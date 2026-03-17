//
//  GlobalHotkeyManager.swift
//  FalconShot
//
//  Created by Dzmitry Sharko on 17.03.2026.
//

import Cocoa
import Carbon

class GlobalHotkeyManager {
    static let shared = GlobalHotkeyManager()
    
    private var eventHandler: EventHandlerRef?
    private var hotKeyRef: EventHotKeyRef?
    private var hotKeyID: EventHotKeyID = EventHotKeyID(signature: 0x46414C43, id: 1) // 'FALC'
    
    var onHotkeyPressed: (() -> Void)?
    
    private init() {}
    
    func registerHotkey(keyCode: UInt16, modifiers: UInt32) -> Bool {
        // Unregister existing hotkey
        unregisterHotkey()
        
        // Create event handler
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        
        let handler: EventHandlerUPP = { (nextHandler, event, userData) -> OSStatus in
            guard let userData = userData else { return OSStatus(eventNotHandledErr) }
            
            let manager = Unmanaged<GlobalHotkeyManager>.fromOpaque(userData).takeUnretainedValue()
            
            DispatchQueue.main.async {
                manager.onHotkeyPressed?()
            }
            
            return noErr
        }
        
        let status = InstallEventHandler(
            GetApplicationEventTarget(),
            handler,
            1,
            &eventType,
            Unmanaged.passUnretained(self).toOpaque(),
            &eventHandler
        )
        
        guard status == noErr else {
            print("Failed to install event handler: \(status)")
            return false
        }
        
        // Register hotkey
        let registerStatus = RegisterEventHotKey(
            UInt32(keyCode),  // Convert UInt16 to UInt32
            modifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )
        
        guard registerStatus == noErr else {
            print("Failed to register hotkey: \(registerStatus)")
            return false
        }
        
        print("✅ Global hotkey registered successfully")
        return true
    }
    
    func unregisterHotkey() {
        if let hotKeyRef = hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
            self.hotKeyRef = nil
        }
        
        if let eventHandler = eventHandler {
            RemoveEventHandler(eventHandler)
            self.eventHandler = nil
        }
    }
    
    deinit {
        unregisterHotkey()
    }
}

// Extension to convert NSEvent.ModifierFlags to Carbon modifiers
extension NSEvent.ModifierFlags {
    var carbonModifiers: UInt32 {
        var carbonMods: UInt32 = 0
        
        if contains(.command) {
            carbonMods |= UInt32(cmdKey)
        }
        if contains(.shift) {
            carbonMods |= UInt32(shiftKey)
        }
        if contains(.option) {
            carbonMods |= UInt32(optionKey)
        }
        if contains(.control) {
            carbonMods |= UInt32(controlKey)
        }
        
        return carbonMods
    }
}

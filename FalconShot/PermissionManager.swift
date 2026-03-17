//
//  PermissionManager.swift
//  FalconShot
//
//  Created by Dzmitry Sharko on 17.03.2026.
//

import Cocoa
import ScreenCaptureKit

class PermissionManager {
    static let shared = PermissionManager()
    
    private init() {}
    
    func checkAndRequestPermissions() {
        Task {
            // Check screen recording permission
            let hasPermission = await checkScreenRecordingPermission()
            
            if !hasPermission {
                showPermissionAlert()
            }
        }
    }
    
    private func checkScreenRecordingPermission() async -> Bool {
        do {
            // Try to get available content - this will trigger permission prompt if needed
            let content = try await SCShareableContent.excludingDesktopWindows(
                false,
                onScreenWindowsOnly: true
            )
            return !content.displays.isEmpty
        } catch {
            return false
        }
    }
    
    @MainActor
    private func showPermissionAlert() {
        let alert = NSAlert()
        alert.messageText = "Screen Recording Permission Required"
        alert.informativeText = "FalconShot needs permission to capture your screen. Please grant Screen Recording permission in System Settings > Privacy & Security > Screen Recording."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Open System Settings")
        alert.addButton(withTitle: "Later")
        
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") {
                NSWorkspace.shared.open(url)
            }
        }
    }
}

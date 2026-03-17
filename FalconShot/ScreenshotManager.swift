//
//  ScreenshotManager.swift
//  FalconShot
//
//  Created by Dzmitry Sharko on 17.03.2026.
//

import SwiftUI
import Combine
import ScreenCaptureKit
import AppKit
import UniformTypeIdentifiers

enum CaptureMode: String, CaseIterable {
    case dynamic = "Dynamic"
    case editRectangle = "Edit the rectangle"
}

enum SaveDestination: String, CaseIterable {
    case buffer = "Buffer"
    case disk = "Disk"
}

class ScreenshotManager: ObservableObject {
    @Published var captureMode: CaptureMode = .dynamic
    @Published var saveDestination: SaveDestination = .buffer
    @Published var previousRect: CGRect?
    @Published var isCapturing: Bool = false
    @Published var captureShortcut: KeyboardShortcut = KeyboardShortcut(keyCode: 22, modifiers: [.command, .shift]) // Default: ⌘⇧6
    
    private var selectionWindow: SelectionOverlayWindow?
    
    init() {
        loadPreferences()
        setupGlobalShortcut()
    }
    
    func setupGlobalShortcut() {
        // Use global hotkey manager for system-wide shortcuts
        GlobalHotkeyManager.shared.onHotkeyPressed = { [weak self] in
            Task { @MainActor in
                self?.startCapture()
            }
        }
        
        // Register the hotkey
        let carbonModifiers = captureShortcut.modifiers.carbonModifiers
        let success = GlobalHotkeyManager.shared.registerHotkey(
            keyCode: captureShortcut.keyCode,
            modifiers: carbonModifiers
        )
        
        if success {
            print("✅ Global shortcut \(captureShortcut.displayString) is active system-wide")
        } else {
            print("⚠️ Failed to register global shortcut. Using menu bar button instead.")
        }
    }
    
    @MainActor
    func startCapture() {
        guard !isCapturing else { return }
        isCapturing = true
        
        switch captureMode {
        case .dynamic:
            showSelectionWindow(initialRect: nil)
        case .editRectangle:
            showSelectionWindow(initialRect: previousRect)
        }
    }
    
    @MainActor
    private func showSelectionWindow(initialRect: CGRect?) {
        selectionWindow = SelectionOverlayWindow(initialRect: initialRect) { [weak self] selectedRect in
            guard let self = self else { return }
            
            if let rect = selectedRect {
                Task { @MainActor in
                    self.previousRect = rect
                }
                Task {
                    await self.captureScreen(rect: rect)
                }
            }
            
            Task { @MainActor in
                self.selectionWindow = nil
                self.isCapturing = false
            }
        }
        
        selectionWindow?.makeKeyAndOrderFront(nil)
    }
    
    func captureScreen(rect: CGRect) async {
        do {
            let content = try await SCShareableContent.excludingDesktopWindows(
                false,
                onScreenWindowsOnly: true
            )
            
            guard let display = content.displays.first else {
                print("No display found")
                return
            }
            
            let filter = SCContentFilter(display: display, excludingWindows: [])
            
            // Get the scale factor from NSScreen
            let scaleFactor = NSScreen.main?.backingScaleFactor ?? 2.0
            
            let config = SCStreamConfiguration()
            config.width = Int(rect.width * scaleFactor)
            config.height = Int(rect.height * scaleFactor)
            config.sourceRect = rect
            
            let image = try await SCScreenshotManager.captureImage(
                contentFilter: filter,
                configuration: config
            )
            
            // Convert CGImage to NSImage
            let nsImage = NSImage(cgImage: image, size: NSSize(width: rect.width, height: rect.height))
            
            // Save based on destination
            await MainActor.run {
                switch saveDestination {
                case .buffer:
                    saveToClipboard(nsImage)
                case .disk:
                    saveToDisk(nsImage)
                }
                
                savePreferences()
            }
            
        } catch {
            print("Failed to capture screen: \(error)")
        }
    }
    
    private func saveToClipboard(_ image: NSImage) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.writeObjects([image])
        
        // Visual feedback - play system sound
        NSSound.beep()
        print("Screenshot copied to clipboard")
    }
    
    private func saveToDisk(_ image: NSImage) {
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            NSSound.beep()
            print("Failed to get CGImage from NSImage")
            return
        }
        
        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [.heic]
        savePanel.canCreateDirectories = true
        savePanel.isExtensionHidden = false
        savePanel.title = "Save Screenshot"
        savePanel.message = "Choose a location to save your screenshot"
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd 'at' HH.mm.ss"
        savePanel.nameFieldStringValue = "Screenshot \(dateFormatter.string(from: Date())).heic"
        
        // Show the panel
        savePanel.begin { response in
            if response == .OK, let url = savePanel.url {
                guard let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.heic.identifier as CFString, 1, nil) else {
                    NSSound.beep()
                    print("Failed to create image destination")
                    return
                }
                
                var finalImage = cgImage
                
                // If the image has an alpha channel bit set but is likely opaque (common for screenshots),
                // recreate it without alpha to avoid HEIC encoder warnings and unnecessary file size.
                if cgImage.alphaInfo != .none {
                    let width = cgImage.width
                    let height = cgImage.height
                    let colorSpace = CGColorSpaceCreateDeviceRGB()
                    let bitmapInfo = CGImageAlphaInfo.noneSkipLast.rawValue | CGBitmapInfo.byteOrder32Little.rawValue
                    
                    if let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0, space: colorSpace, bitmapInfo: bitmapInfo) {
                        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: CGFloat(width), height: CGFloat(height)))
                        if let strippedImage = context.makeImage() {
                            finalImage = strippedImage
                        }
                    }
                }
                
                let options: [CFString: Any] = [
                    kCGImageDestinationLossyCompressionQuality: 0.9
                ]
                
                CGImageDestinationAddImage(destination, finalImage, options as CFDictionary)
                
                if CGImageDestinationFinalize(destination) {
                    NSSound.beep()
                    print("Screenshot saved to: \(url.path)")
                } else {
                    NSSound.beep()
                    NSSound.beep()
                    print("Failed to finalize image destination")
                }
            }
        }
    }
    
    // MARK: - Preferences
    
    private func loadPreferences() {
        if let modeRaw = UserDefaults.standard.string(forKey: "captureMode"),
           let mode = CaptureMode(rawValue: modeRaw) {
            captureMode = mode
        }
        
        if let destRaw = UserDefaults.standard.string(forKey: "saveDestination"),
           let dest = SaveDestination(rawValue: destRaw) {
            saveDestination = dest
        }
        
        // Load keyboard shortcut
        if let shortcutData = UserDefaults.standard.data(forKey: "captureShortcut"),
           let savedShortcut = try? JSONDecoder().decode(KeyboardShortcut.self, from: shortcutData) {
            captureShortcut = savedShortcut
        }
        
        if let rectData = UserDefaults.standard.data(forKey: "previousRect"),
           let rect = try? NSKeyedUnarchiver.unarchivedObject(ofClass: NSValue.self, from: rectData) {
            previousRect = rect.rectValue
        }
    }
    
    func savePreferences() {
        UserDefaults.standard.set(captureMode.rawValue, forKey: "captureMode")
        UserDefaults.standard.set(saveDestination.rawValue, forKey: "saveDestination")
        
        // Save keyboard shortcut
        if let shortcutData = try? JSONEncoder().encode(captureShortcut) {
            UserDefaults.standard.set(shortcutData, forKey: "captureShortcut")
        }
        
        if let rect = previousRect {
            let rectValue = NSValue(rect: rect)
            if let data = try? NSKeyedArchiver.archivedData(withRootObject: rectValue, requiringSecureCoding: true) {
                UserDefaults.standard.set(data, forKey: "previousRect")
            }
        }
        
        // Re-register global shortcut when it changes
        setupGlobalShortcut()
    }
    
    deinit {
        // Unregister global hotkey
        GlobalHotkeyManager.shared.unregisterHotkey()
        
        // Clean up selection window
        if let window = selectionWindow {
            window.close()
            selectionWindow = nil
        }
    }
}

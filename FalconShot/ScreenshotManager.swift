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
import ServiceManagement

enum CaptureMode: String, CaseIterable {
    case dynamic = "Dynamic"
    case editRectangle = "Edit the rectangle"
}

enum SaveDestination: String, CaseIterable {
    case buffer = "Buffer"
    case disk = "Disk"
}

class ScreenshotManager: ObservableObject {
    @Published var loadOnStartup: Bool = true {
        didSet { 
            savePreferences() 
            updateStartupRegistration()
        }
    }
    @Published var captureMode: CaptureMode = .dynamic {
        didSet { savePreferences() }
    }
    @Published var saveDestination: SaveDestination = .buffer {
        didSet { savePreferences() }
    }
    @Published var previousRect: CGRect? {
        didSet { savePreferences() }
    }
    @Published var isCapturing: Bool = false
    @Published var captureShortcut: KeyboardShortcut = KeyboardShortcut(keyCode: 22, modifiers: [.command, .shift]) { // Default: ⌘⇧6
        didSet {
            savePreferences()
            setupGlobalShortcut()
        }
    }
    
    private var selectionWindow: SelectionOverlayWindow?
    
    init() {
        // Load initial values from UserDefaults
        if let startup = UserDefaults.standard.object(forKey: "loadOnStartup") as? Bool {
            _loadOnStartup = Published(initialValue: startup)
        } else {
            // Default to true
            _loadOnStartup = Published(initialValue: true)
        }
        
        // Ensure system registration is in sync with UserDefaults preference
        updateStartupRegistration()
        
        if let modeRaw = UserDefaults.standard.string(forKey: "captureMode"),
           let mode = CaptureMode(rawValue: modeRaw) {
            _captureMode = Published(initialValue: mode)
        }
        
        if let destRaw = UserDefaults.standard.string(forKey: "saveDestination"),
           let dest = SaveDestination(rawValue: destRaw) {
            _saveDestination = Published(initialValue: dest)
        }
        
        if let shortcutData = UserDefaults.standard.data(forKey: "captureShortcut"),
           let savedShortcut = try? JSONDecoder().decode(KeyboardShortcut.self, from: shortcutData) {
            _captureShortcut = Published(initialValue: savedShortcut)
        }
        
        if let rectData = UserDefaults.standard.data(forKey: "previousRect"),
           let rect = try? NSKeyedUnarchiver.unarchivedObject(ofClass: NSValue.self, from: rectData) {
            _previousRect = Published(initialValue: rect.rectValue)
        }
        
        setupGlobalShortcut()
    }
    
    func setupGlobalShortcut() {
        // Unregister existing first to avoid duplicates or conflicts
        GlobalHotkeyManager.shared.unregisterHotkey()
        
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
            Log.info("Global shortcut \(captureShortcut.displayString) is active system-wide")
        } else {
            Log.error("Failed to register global shortcut. Using menu bar button instead.")
        }
    }
    
    private func updateStartupRegistration() {
        do {
            if loadOnStartup {
                if SMAppService.mainApp.status != .enabled {
                    try SMAppService.mainApp.register()
                    Log.info("SMAppService registered")
                }
            } else {
                if SMAppService.mainApp.status == .enabled {
                    try SMAppService.mainApp.unregister()
                    Log.info("SMAppService unregistered")
                }
            }
        } catch {
            Log.error("Failed to update SMAppService: \(error)")
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
            
            // Match SCDisplay by frame — SCDisplay.frame is in global screen coordinates (points).
            let display = content.displays.first {
                NSMouseInRect(NSPoint(x: rect.midX, y: rect.midY),
                              CGRect(x: $0.frame.origin.x, y: $0.frame.origin.y,
                                     width: $0.frame.width, height: $0.frame.height), false)
            } ?? content.displays.first

            guard let display else {
                Log.error("No display found")
                return
            }

            let filter = SCContentFilter(display: display, excludingWindows: [])

            // Capture the full display at its native pixel resolution.
            // We set width/height = display.width/height (physical pixels) so SCKit
            // renders 1:1 without any scaling. Then we crop the selection manually.
            // This avoids the blur from scaling the canvas down to rect size.
            let config = SCStreamConfiguration()
            config.width = display.width    // native physical pixels, e.g. 3840
            config.height = display.height  // native physical pixels, e.g. 2160
            let fullImage = try await SCScreenshotManager.captureImage(
                contentFilter: filter,
                configuration: config
            )

            // renderScale = physical pixels per logical point
            let renderScale = CGFloat(fullImage.width) / display.frame.width

            // Crop: rect uses top-left origin (from SelectionView), SCKit image too.
            let cropRect = CGRect(
                x: rect.origin.x * renderScale,
                y: rect.origin.y * renderScale,
                width: rect.width * renderScale,
                height: rect.height * renderScale
            )
            guard let cgCropped = fullImage.cropping(to: cropRect) else {
                Log.error("Failed to crop image")
                return
            }

            let rep = NSBitmapImageRep(cgImage: cgCropped)
            let nsImage = NSImage(size: rep.size)
            nsImage.addRepresentation(rep)

            Log.debug("rect=\(Int(rect.width))×\(Int(rect.height))pt renderScale=\(renderScale) crop=\(Int(cropRect.width))×\(Int(cropRect.height))px")

            // Save based on destination
            await MainActor.run {
                switch saveDestination {
                case .buffer:
                    saveToClipboard(nsImage)
                case .disk:
                    saveToDisk(nsImage)
                }
            }
            
        } catch {
            Log.error("Failed to capture screen: \(error)")
        }
    }

    private func saveToClipboard(_ image: NSImage) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()

        guard let rep = image.representations.first as? NSBitmapImageRep else {
            pasteboard.writeObjects([image])
            NSSound.beep()
            Log.info("Screenshot copied to clipboard (fallback)")
            return
        }

        if let png = rep.representation(using: .png, properties: [:]) {
            pasteboard.setData(png, forType: .png)
            Log.debug("clipboard: PNG \(rep.pixelsWide)×\(rep.pixelsHigh)px \(png.count / 1024)KB")
        } else {
            pasteboard.writeObjects([image])
            Log.debug("clipboard: fallback NSImage")
        }

        NSSound.beep()
        Log.info("Screenshot copied to clipboard")
    }
    
    private func saveToDisk(_ image: NSImage) {
        // Use the backing CGImage directly from the first representation to avoid
        // NSImage rescaling to 1x when proposedRect is nil.
        guard let cgImage = (image.representations.first as? NSBitmapImageRep)?.cgImage
                ?? image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            NSSound.beep()
            Log.error("Failed to get CGImage from NSImage")
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
                    Log.error("Failed to create image destination")
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
                
                let repForDPI = image.representations.first as? NSBitmapImageRep
                let dpi = repForDPI.map { 72.0 * CGFloat($0.pixelsWide) / $0.size.width } ?? 144.0
                let options: [CFString: Any] = [
                    kCGImageDestinationLossyCompressionQuality: 0.9,
                    kCGImagePropertyDPIWidth: dpi,
                    kCGImagePropertyDPIHeight: dpi,
                ]
                
                CGImageDestinationAddImage(destination, finalImage, options as CFDictionary)
                
                if CGImageDestinationFinalize(destination) {
                    NSSound.beep()
                    Log.info("Screenshot saved to: \(url.path)")
                } else {
                    NSSound.beep()
                    NSSound.beep()
                    Log.error("Failed to finalize image destination")
                }
            }
        }
    }
    
    // MARK: - Preferences
    
    
    func savePreferences() {
        UserDefaults.standard.set(loadOnStartup, forKey: "loadOnStartup")
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

//
//  MenuBarView.swift
//  FalconShot
//
//  Created by Dzmitry Sharko on 17.03.2026.
//

import SwiftUI

struct MenuBarView: View {
    @EnvironmentObject var screenshotManager: ScreenshotManager
    
    var body: some View {
        VStack(spacing: 0) {
            // Capture button
            Button("Capture Screenshot (\(screenshotManager.captureShortcut.displayString))") {
                screenshotManager.startCapture()
            }
            
            Divider()
            
            // Shortcuts submenu
            Menu("Shortcuts") {
                Text("\(screenshotManager.captureShortcut.displayString) - Take Screenshot")
                Text("ESC - Cancel")
            }
            
            Divider()
            
            // Mode submenu
            Menu("Mode") {
                ForEach(CaptureMode.allCases, id: \.self) { mode in
                    Button {
                        screenshotManager.captureMode = mode
                    } label: {
                        HStack {
                            Text(mode.rawValue)
                            if screenshotManager.captureMode == mode {
                                Spacer()
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            }
            
            Divider()
            
            // Save Destination submenu
            Menu("Save Destination") {
                ForEach(SaveDestination.allCases, id: \.self) { destination in
                    Button {
                        screenshotManager.saveDestination = destination
                    } label: {
                        HStack {
                            Text(destination.rawValue)
                            if screenshotManager.saveDestination == destination {
                                Spacer()
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            }
            
            Divider()
            
            // Settings - Use SettingsLink for proper Settings scene
            SettingsLink {
                Text("Settings...")
            }
            .keyboardShortcut(",", modifiers: .command)
            
            Divider()
            
            // Exit
            Button("Quit FalconShot") {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q", modifiers: .command)
        }
        .frame(width: 250)
    }
}

#Preview {
    MenuBarView()
        .environmentObject(ScreenshotManager())
}

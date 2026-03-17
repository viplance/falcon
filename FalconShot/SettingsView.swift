//
//  SettingsView.swift
//  FalconShot
//
//  Created by Dzmitry Sharko on 17.03.2026.
//

import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var screenshotManager: ScreenshotManager
    
    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Capture Settings
                GroupBox {
                    VStack(alignment: .leading, spacing: 12) {
                        Picker("Capture Mode:", selection: $screenshotManager.captureMode) {
                            ForEach(CaptureMode.allCases, id: \.self) { mode in
                                Text(mode.rawValue).tag(mode)
                            }
                        }
                        .pickerStyle(.menu)
                        
                        Picker("Save Destination:", selection: $screenshotManager.saveDestination) {
                            ForEach(SaveDestination.allCases, id: \.self) { destination in
                                Text(destination.rawValue).tag(destination)
                            }
                        }
                        .pickerStyle(.menu)
                        
                        Text("Changes are saved automatically")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                } label: {
                    Text("Capture Settings")
                        .font(.headline)
                }
                .padding(.horizontal)
                .padding(.vertical)
                
                
                // Keyboard Shortcuts
                GroupBox {
                    VStack(alignment: .leading, spacing: 16) {
                        HStack(spacing: 20) {
                            Text("Take Screenshot:")
                                .frame(width: 140, alignment: .leading)
                            
                            // Create a binding that wraps the non-optional in an optional
                            let binding = Binding<KeyboardShortcut?>(
                                get: { screenshotManager.captureShortcut },
                                set: { newValue in
                                    if let newValue = newValue {
                                        screenshotManager.captureShortcut = newValue
                                    }
                                }
                            )
                            
                            KeyRecorderView(
                                shortcut: binding,
                                placeholder: "Click to set"
                            )
                            .frame(width: 200)
                            Spacer()
                        }
                        
                        HStack(spacing: 20) {
                            Text("Cancel Selection:")
                                .frame(width: 140, alignment: .leading)
                            Text("ESC")
                                .font(.system(.body, design: .monospaced))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(.quaternary)
                                .cornerRadius(4)
                            Spacer()
                        }
                        
                        
                        Text("Click the shortcut field to record a new key combination.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding()
                } label: {
                    Text("Keyboard Shortcuts")
                        .font(.headline)
                }
                .padding(.horizontal)
                .padding(.bottom)
                
                // About
                GroupBox {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "camera.viewfinder")
                                .font(.title)
                                .foregroundStyle(.blue)
                            VStack(alignment: .leading, spacing: 4) {
                                Text("FalconShot")
                                    .font(.headline)
                                Text("Version 1.0")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        
                        Divider()
                            .padding(.vertical, 4)
                        
                        Text("A powerful screenshot utility for macOS")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        
                        Text("Created by Dzmitry Sharko")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                    .padding()
                } label: {
                    Text("About")
                        .font(.headline)
                }
                .padding(.horizontal)
                .padding(.bottom)
            }
        }
        .frame(width: 550, height: 600)
    }
}

#Preview {
    SettingsView()
        .environmentObject(ScreenshotManager())
}

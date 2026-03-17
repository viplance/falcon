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
                } label: {
                    Text("Capture Settings")
                        .font(.headline)
                }
                .padding()
                
                // Previous Rectangle
                GroupBox {
                    VStack(alignment: .leading, spacing: 12) {
                        if let rect = screenshotManager.previousRect {
                            Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 6) {
                                GridRow {
                                    Text("X:")
                                        .foregroundStyle(.secondary)
                                        .frame(width: 60, alignment: .trailing)
                                    Text(String(format: "%.0f px", rect.origin.x))
                                        .font(.system(.body, design: .monospaced))
                                }
                                
                                GridRow {
                                    Text("Y:")
                                        .foregroundStyle(.secondary)
                                        .frame(width: 60, alignment: .trailing)
                                    Text(String(format: "%.0f px", rect.origin.y))
                                        .font(.system(.body, design: .monospaced))
                                }
                                
                                GridRow {
                                    Text("Width:")
                                        .foregroundStyle(.secondary)
                                        .frame(width: 60, alignment: .trailing)
                                    Text(String(format: "%.0f px", rect.width))
                                        .font(.system(.body, design: .monospaced))
                                }
                                
                                GridRow {
                                    Text("Height:")
                                        .foregroundStyle(.secondary)
                                        .frame(width: 60, alignment: .trailing)
                                    Text(String(format: "%.0f px", rect.height))
                                        .font(.system(.body, design: .monospaced))
                                }
                            }
                            
                            Button("Clear Previous Rectangle") {
                                screenshotManager.previousRect = nil
                            }
                            .buttonStyle(.borderless)
                            .foregroundStyle(.red)
                        } else {
                            Text("No previous selection saved")
                                .foregroundStyle(.secondary)
                                .font(.subheadline)
                        }
                    }
                    .padding()
                } label: {
                    Text("Previous Rectangle")
                        .font(.headline)
                }
                .padding(.horizontal)
                .padding(.bottom)
                
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
                                        screenshotManager.savePreferences()
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
                        
                        HStack(spacing: 20) {
                            Text("Open Settings:")
                                .frame(width: 140, alignment: .leading)
                            Text("⌘,")
                                .font(.system(.body, design: .monospaced))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(.quaternary)
                                .cornerRadius(4)
                            Spacer()
                        }
                        
                        HStack(spacing: 20) {
                            Text("Quit FalconShot:")
                                .frame(width: 140, alignment: .leading)
                            Text("⌘Q")
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

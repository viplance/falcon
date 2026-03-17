//
//  KeyRecorderView.swift
//  FalconShot
//
//  Created by Dzmitry Sharko on 17.03.2026.
//

import SwiftUI
import AppKit

struct KeyRecorderView: View {
    @Binding var shortcut: KeyboardShortcut?
    let placeholder: String
    
    @State private var isRecording = false
    @State private var eventMonitor: Any?
    
    var body: some View {
        HStack {
            Button(action: {
                if isRecording {
                    stopRecording()
                } else {
                    startRecording()
                }
            }) {
                HStack {
                    if isRecording {
                        Text("Press keys...")
                            .foregroundStyle(.secondary)
                    } else if let shortcut = shortcut {
                        Text(shortcut.displayString)
                            .font(.system(.body, design: .monospaced))
                    } else {
                        Text(placeholder)
                            .foregroundStyle(.secondary)
                    }
                    
                    Spacer()
                    
                    Image(systemName: isRecording ? "stop.circle.fill" : "keyboard")
                        .foregroundStyle(isRecording ? .red : .blue)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .frame(minWidth: 150)
                .background(isRecording ? Color.blue.opacity(0.1) : Color.gray.opacity(0.1))
                .cornerRadius(6)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(isRecording ? Color.blue : Color.clear, lineWidth: 2)
                )
            }
            .buttonStyle(.plain)
            
            if shortcut != nil {
                Button(action: {
                    shortcut = nil
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("Clear shortcut")
            }
        }
    }
    
    private func startRecording() {
        isRecording = true
        
        // Use local event monitor to capture key presses
        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            // ESC to cancel
            if event.keyCode == 53 {
                self.stopRecording()
                return nil
            }
            
            // Require at least one modifier key
            let modifiers = event.modifierFlags.intersection([.command, .control, .option, .shift])
            
            guard !modifiers.isEmpty else {
                NSSound.beep()
                return nil
            }
            
            // Don't allow just Command key (conflicts with menu shortcuts)
            if modifiers == .command {
                NSSound.beep()
                return nil
            }
            
            // Create and save shortcut
            let newShortcut = KeyboardShortcut(
                keyCode: event.keyCode,
                modifiers: modifiers
            )
            
            self.shortcut = newShortcut
            self.stopRecording()
            
            return nil // Consume the event
        }
    }
    
    private func stopRecording() {
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
        isRecording = false
    }
}

//
//  ContentView.swift
//  FalconShot
//
//  Created by Dzmitry Sharko on 17.03.2026.
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var screenshotManager: ScreenshotManager
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "camera.viewfinder")
                .imageScale(.large)
                .font(.system(size: 60))
                .foregroundStyle(.tint)
            
            Text("FalconShot")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            Text("Screenshot Utility")
                .font(.headline)
                .foregroundStyle(.secondary)
            
            Divider()
                .padding(.vertical)
            
            VStack(alignment: .leading, spacing: 12) {
                Text("Quick Start:")
                    .font(.headline)
                
                HStack {
                    Text("⌘⇧5")
                        .font(.system(.body, design: .monospaced))
                        .padding(4)
                        .background(.quaternary)
                        .cornerRadius(4)
                    Text("Take a screenshot")
                }
                
                HStack {
                    Text("ESC")
                        .font(.system(.body, design: .monospaced))
                        .padding(4)
                        .background(.quaternary)
                        .cornerRadius(4)
                    Text("Cancel selection")
                }
            }
            
            Spacer()
            
            Text("Click the camera icon in the menu bar to access settings")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(40)
        .frame(minWidth: 400, minHeight: 400)
    }
}

#Preview {
    ContentView()
        .environmentObject(ScreenshotManager())
}

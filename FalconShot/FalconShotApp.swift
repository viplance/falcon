//
//  FalconShotApp.swift
//  FalconShot
//
//  Created by Dzmitry Sharko on 17.03.2026.
//

import SwiftUI

@main
struct FalconShotApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var screenshotManager = ScreenshotManager()
    
    var body: some Scene {
        MenuBarExtra("FalconShot", systemImage: "camera.viewfinder") {
            MenuBarView()
                .environmentObject(screenshotManager)
        }
        .menuBarExtraStyle(.menu)
        
        Settings {
            SettingsView()
                .environmentObject(screenshotManager)
        }
        .commands {
            CommandGroup(replacing: .appSettings) {}
            CommandGroup(replacing: .appTermination) {}
        }
    }
}

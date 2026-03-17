//
//  AppDelegate.swift
//  FalconShot
//
//  Created by Dzmitry Sharko on 17.03.2026.
//

import Cocoa
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Check screen recording permissions
        PermissionManager.shared.checkAndRequestPermissions()
    }
}

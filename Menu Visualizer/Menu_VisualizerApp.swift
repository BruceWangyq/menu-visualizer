//
//  Menu_VisualizerApp.swift
//  Menu Visualizer
//
//  Created by wang yuqiu on 2025-08-19.
//

import SwiftUI
import FirebaseCore

@main
struct Menu_VisualizerApp: App {
    init() {
        // Initialize Firebase
        FirebaseApp.configure()
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

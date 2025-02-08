//
//  FriendlyApp.swift
//  Friendly
//
//  Created by Nathan Mercier on 07/02/2025.
//

import SwiftUI
import FirebaseCore

@main
struct FriendCryptApp: App {
    // Initialize Firebase when the app starts.
    init() {
        FirebaseApp.configure()
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

//
//  ContentView.swift
//  Friendly
//
//  Created by Nathan Mercier on 07/02/2025.
//

import SwiftUI

struct ContentView: View {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @ObservedObject var authVM = AuthViewModel.shared
    @StateObject var router = NavigationRouter.shared
    
    var body: some View {
        if authVM.isLoggedIn {
            HomeView()
                .environmentObject(router)
                .onAppear {
                    if let pending = appDelegate.pendingDeepLink {
                        router.navigate(to: pending)
                        appDelegate.pendingDeepLink = nil
                    }
                }
        } else {
            LoginView()
        }
    }
}

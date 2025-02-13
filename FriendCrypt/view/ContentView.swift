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
    @StateObject var friendVM = FriendViewModel()
    
    var body: some View {
        Group {
            if authVM.isLoggedIn {
                if let user = authVM.user {
                    if !user.friends.isEmpty && friendVM.friends.isEmpty {
                        SplashView(message: "Loading friend data...")
                    } else {
                        HomeView()
                            .environmentObject(router)
                            .environmentObject(friendVM)
                            .onAppear {
                                if let pending = appDelegate.pendingDeepLink {
                                    router.navigate(to: pending)
                                    appDelegate.pendingDeepLink = nil
                                }
                            }
                    }
                } else {
                    SplashView(message: "Loading user...")
                }
            } else {
                LoginView()
            }
        }
        .onAppear {
            if let user = authVM.user {
                friendVM.fetchFriends(for: user)
            }
        }
        .onChange(of: authVM.user?.id) {
            if let user = authVM.user {
                friendVM.fetchFriends(for: user)
            }
        }
    }
}

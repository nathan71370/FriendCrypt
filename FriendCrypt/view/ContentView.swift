//
//  ContentView.swift
//  Friendly
//
//  Created by Nathan Mercier on 07/02/2025.
//

import SwiftUI

struct ContentView: View {
    @ObservedObject var authVM = AuthViewModel.shared
    
    var body: some View {
        if authVM.isLoggedIn {
            HomeView()
        } else {
            LoginView()
        }
    }
}

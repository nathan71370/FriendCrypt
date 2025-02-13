//
//  SplashView.swift
//  FriendCrypt
//
//  Created by Nathan Mercier on 13/02/2025.
//


import SwiftUI

struct SplashView: View {
    var message: String = "Loading..."
    
    var body: some View {
        VStack {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle())
                .scaleEffect(1.5)
            Text(message)
                .padding(.top, 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
    }
}

//
//  FriendDetailView.swift
//  Friendly
//
//  Created by Nathan Mercier on 08/02/2025.
//


import SwiftUI

struct FriendDetailView: View {
    let friend: ChatUser
    
    var body: some View {
        VStack(spacing: 20) {
            Text(friend.username)
                .font(.largeTitle)
            Text(friend.email)
                .font(.subheadline)
            Spacer()
        }
        .padding()
        .navigationTitle("Friend Details")
    }
}
//
//  FriendRow.swift
//  Friendly
//
//  Created by Nathan Mercier on 08/02/2025.
//

import SwiftUI

struct FriendRow: View {
    let friend: ChatUser
    
    var body: some View {
        HStack(spacing: 15) {
            VStack(alignment: .leading) {
                Text(friend.username)
                    .font(.headline)
                Text(friend.email)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            Spacer()
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle())
    }
}

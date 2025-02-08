//
//  FriendRequestsView.swift
//  Friendly
//
//  Created by Nathan Mercier on 08/02/2025.
//

import SwiftUI

struct FriendRequestsView: View {
    @EnvironmentObject var authVM: AuthViewModel
    @StateObject var friendRequestsVM = FriendRequestsViewModel()
    
    var body: some View {
        NavigationView {
            VStack {
                if friendRequestsVM.friendRequests.isEmpty {
                    Text("You don't have any pending friend requests.")
                        .font(.headline)
                } else {
                    List {
                        ForEach(friendRequestsVM.friendRequests) { requestUser in
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(requestUser.username)
                                        .font(.headline)
                                    Text(requestUser.email)
                                        .font(.subheadline)
                                }
                                Spacer()
                                HStack {
                                    Button(action: {
                                        if let currentUser = authVM.user {
                                            friendRequestsVM.acceptRequest(from: requestUser, currentUser: currentUser) { updatedUser in
                                                if let updatedUser = updatedUser {
                                                    DispatchQueue.main.async {
                                                        authVM.user = updatedUser
                                                        NotificationCenter.default.post(name: .friendListUpdated, object: nil)
                                                    }
                                                }
                                            }
                                        }
                                    }) {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(.green)
                                            .font(.title2)
                                    }
                                    .buttonStyle(BorderlessButtonStyle())
                                    .padding(.trailing, 8)
                                    
                                    Button(action: {
                                        if let currentUser = authVM.user {
                                            friendRequestsVM.rejectRequest(from: requestUser, currentUser: currentUser)
                                        }
                                    }) {
                                        Image(systemName: "xmark.circle.fill")
                                            .foregroundColor(.red)
                                            .font(.title2)
                                    }
                                    .buttonStyle(BorderlessButtonStyle())
                                }
                            }
                            .padding(.vertical, 8)
                        }
                    }
                }
            }
            .navigationTitle("Friend Requests")
            .onAppear {
                if let currentUser = authVM.user {
                    friendRequestsVM.fetchFriendRequests(for: currentUser)
                }
            }
        }
    }
}

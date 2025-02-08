//
//  HomeView.swift
//  Friendly
//
//  Created by Nathan Mercier on 07/02/2025.
//
import SwiftUI

extension Notification.Name {
    static let friendListUpdated = Notification.Name("friendListUpdated")
}

struct FriendView: View {
    @EnvironmentObject var authVM: AuthViewModel
    @StateObject var friendVM = FriendViewModel()
    @State private var showAddFriend = false
    @State private var showFriendRequests = false
    @State private var friendToDelete: ChatUser? = nil
    
    var body: some View {
        NavigationView {
            List {
                if friendVM.friends.isEmpty {
                    Text("No friends yet")
                } else {
                    ForEach(friendVM.friends) { friend in
                        NavigationLink(destination: FriendDetailView(friend: friend)) {
                            FriendRow(friend: friend)
                        }
                        .buttonStyle(PlainButtonStyle())
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                friendToDelete = friend
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                }
            }
            .listStyle(PlainListStyle())
            .navigationTitle("Friends")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        showFriendRequests.toggle()
                    } label: {
                        Image(systemName: "person.fill.questionmark")
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showAddFriend.toggle()
                    } label: {
                        Image(systemName: "person.badge.plus")
                    }
                }
            }
            .sheet(isPresented: $showAddFriend) {
                AddFriendView()
            }
            .sheet(isPresented: $showFriendRequests) {
                FriendRequestsView().environmentObject(authVM)
            }
            .alert(item: $friendToDelete) { friend in
                Alert(
                    title: Text("Delete Friend"),
                    message: Text("Are you sure you want to delete \(friend.username)?"),
                    primaryButton: .destructive(Text("Delete")) {
                        if let currentUser = authVM.user, let friendID = friend.id {
                            friendVM.deleteFriend(friend: friend, currentUser: currentUser)
                            var updatedUser = currentUser
                            updatedUser.friends.removeAll { $0 == friendID }
                            authVM.user = updatedUser
                            friendVM.fetchFriends(for: updatedUser)
                        }
                    },
                    secondaryButton: .cancel()
                )
            }
        }
        .onAppear {
            if let currentUser = authVM.user {
                friendVM.fetchFriends(for: currentUser)
            }
        }
        .onReceive(authVM.$user) { user in
            if let user = user {
                friendVM.fetchFriends(for: user)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .friendListUpdated)) { _ in
            if let currentUser = authVM.user {
                friendVM.fetchFriends(for: currentUser)
            }
        }
    }
}

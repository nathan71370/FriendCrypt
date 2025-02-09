//
//  HomeView.swift
//  Friendly
//
//  Created by Nathan Mercier on 07/02/2025.
//

import SwiftUI

struct HomeView: View {
    @ObservedObject var authVM = AuthViewModel.shared
    @StateObject var conversationsVM = ConversationsViewModel()
    @StateObject var friendVM = FriendViewModel()
    
    @State private var showFriend = false
    @State private var showNewConversation = false
    @State private var conversationToQuit: Conversation? = nil
    
    var body: some View {
        NavigationView {
            List {
                ForEach(conversationsVM.conversations) { convo in
                    NavigationLink(destination: ChatView(conversationId: convo.id ?? "")) {
                        VStack(alignment: .leading) {
                            if convo.participants.count == 2 {
                                Text("\(friendVM.friendName(for: convo))")
                                    .font(.headline)
                            } else if convo.participants.count == 1 {
                                Text(authVM.user?.username ?? "Chat").font(.headline)
                            } else {
                                Text("\(convo.participants.count) people").font(.headline)
                            }
                            Text(convo.lastMessage)
                                .font(.subheadline)
                        }
                    }
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            conversationToQuit = convo
                        } label: {
                            Label("Quit", systemImage: "person.fill.xmark")
                        }
                    }
                }
            }
            .navigationTitle("Conversations")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Logout") {
                        authVM.signOut()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        showFriend.toggle()
                    }) {
                        Image(systemName: "person.crop.rectangle.stack")
                    }
                }
                ToolbarItem(placement: .bottomBar) {
                    Button("New Conversation") {
                        showNewConversation.toggle()
                    }
                }
            }
            .sheet(isPresented: $showFriend) {
                FriendView().environmentObject(authVM)
            }
            .sheet(isPresented: $showNewConversation) {
                NewConversationView(isPresented: $showNewConversation)
            }
            .alert(item: $conversationToQuit) { convo in
                Alert(
                    title: Text("Quit Conversation"),
                    message: Text("Are you sure you want to quit this conversation?"),
                    primaryButton: .destructive(Text("Quit"), action: {
                        if let currentUser = authVM.user {
                            conversationsVM.quitConversation(convo: convo, currentUser: currentUser)
                        }
                    }),
                    secondaryButton: .cancel()
                )
            }
        }
        .onAppear {
            if let currentUser = authVM.user {
                friendVM.fetchFriends(for: currentUser)
                conversationsVM.startListening(for: currentUser)
            }
        }
        .onReceive(authVM.$user) { user in
            if let user = user {
                friendVM.fetchFriends(for: user)
                conversationsVM.startListening(for: user)
            } else {
                conversationsVM.stopListening()
            }
        }
    }
}

//
//  HomeView.swift
//  Friendly
//
//  Created by Nathan Mercier on 07/02/2025.
//

import SwiftUI

struct HomeView: View {
    @ObservedObject var authVM = AuthViewModel.shared
    @EnvironmentObject var conversationsVM: ConversationsViewModel
    @EnvironmentObject var friendVM: FriendViewModel
    @EnvironmentObject var router: NavigationRouter
    @State private var showFriend = false
    @State private var showNewConversation = false
    @State private var conversationToQuit: Conversation? = nil

    var body: some View {
        Group {
            if shouldShowLoading {
                loadingView
            } else {
                conversationsNavigationStack
            }
        }
    }
    
    // MARK: - Loading View
    
    private var loadingView: some View {
        ProgressView("Loading friend data...")
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Main NavigationStack
    
    private var conversationsNavigationStack: some View {
        NavigationStack(path: $router.path) {
            List {
                ForEach(Array(conversationsVM.sortedConversations), id: \.id) { convo in
                    NavigationLink(value: DeepLink.conversation(id: convo.id ?? "")) {
                        conversationRow(for: convo)
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
            .toolbar { toolbarContent }
            .sheet(isPresented: $showFriend) {
                FriendView()
                    .environmentObject(authVM)
            }
            .sheet(isPresented: $showNewConversation) {
                NewConversationView(isPresented: $showNewConversation)
            }
            .alert(item: $conversationToQuit) { convo in
                conversationQuitAlert(for: convo)
            }
            .navigationDestination(for: DeepLink.self) { link in
                switch link {
                case .conversation(let id):
                    ChatView(conversationId: id)
                        .environmentObject(friendVM)
                        .environmentObject(conversationsVM)
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .navigateToConversation)) { notification in
                if let userInfo = notification.userInfo,
                   let conversationId = userInfo["conversationId"] as? String {
                    router.navigate(to: .conversation(id: conversationId))
                }
            }
        }
    }
    
    // MARK: - Conversation Row
    
    private func conversationRow(for convo: Conversation) -> some View {
        ConversationRowView(conversation: convo)
    }
    
    // MARK: - Toolbar Content
    
    private var toolbarContent: some ToolbarContent {
        Group {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Logout") {
                    authVM.signOut()
                }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showFriend.toggle()
                } label: {
                    Image(systemName: "person.crop.rectangle.stack")
                }
            }
            ToolbarItem(placement: .bottomBar) {
                Button("New Conversation") {
                    showNewConversation.toggle()
                }
            }
        }
    }
    
    // MARK: - Quit Conversation Alert
    
    private func conversationQuitAlert(for convo: Conversation) -> Alert {
        Alert(
            title: Text("Quit Conversation"),
            message: Text("Are you sure you want to quit this conversation?"),
            primaryButton: .destructive(Text("Quit")) {
                if let currentUser = authVM.user {
                    conversationsVM.quitConversation(convo: convo, currentUser: currentUser)
                }
            },
            secondaryButton: .cancel()
        )
    }
    
    // MARK: - Loading Condition
    
    private var shouldShowLoading: Bool {
        if let user = authVM.user, !user.friends.isEmpty {
            return friendVM.friends.isEmpty
        }
        return false
    }
}

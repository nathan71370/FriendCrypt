//
//  ChatView.swift
//  Friendly
//
//  Created by Nathan Mercier on 07/02/2025.
//

import SwiftUI

struct ChatView: View {
    let conversationId: String
    @ObservedObject var chatVM: ChatViewModel
    @State private var messageText = ""
    @ObservedObject var authVM = AuthViewModel.shared
    @StateObject private var convDetailVM: ConversationDetailViewModel
    @StateObject private var friendVM = FriendViewModel() // Used for lookups
    @State private var showInfoSheet = false
    
    init(conversationId: String) {
        self.conversationId = conversationId
        self.chatVM = ChatViewModel(conversationId: conversationId)
        _convDetailVM = StateObject(wrappedValue: ConversationDetailViewModel(conversationId: conversationId))
    }
    
    /// Compute the navigation title:
    /// - If exactly two participants, look up the other user’s username.
    /// - Otherwise, show the number of people.
    private var navigationTitle: String {
        if let conversation = convDetailVM.conversation {
            if conversation.participants.count == 2 {
                if let currentId = authVM.user?.id,
                   let friendId = conversation.participants.first(where: { $0 != currentId }) {
                    let friendName = friendVM.friends.first(where: { $0.id == friendId })?.username
                    return friendName ?? friendId
                } else {
                    return "Chat"
                }
            } else {
                return "\(conversation.participants.count) people"
            }
        }
        return "Chat"
    }
    
    var body: some View {
        VStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(chatVM.messages) { message in
                        HStack {
                            if message.senderId == authVM.user?.id {
                                Spacer()
                                Text(message.text)
                                    .padding()
                                    .background(Color.blue)
                                    .foregroundColor(.white)
                                    .cornerRadius(8)
                            } else {
                                Text(message.text)
                                    .padding()
                                    .background(Color.gray.opacity(0.2))
                                    .cornerRadius(8)
                                Spacer()
                            }
                        }
                    }
                }
                .padding()
            }
            HStack {
                TextField("Message...", text: $messageText)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                Button("Send") {
                    let trimmed = messageText.trimmingCharacters(in: .whitespaces)
                    if !trimmed.isEmpty {
                        chatVM.sendMessage(text: trimmed)
                        messageText = ""
                    }
                }
            }
            .padding()
        }
        .navigationTitle(navigationTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: { showInfoSheet = true }) {
                    Image(systemName: "info.circle")
                }
            }
        }
        .sheet(isPresented: $showInfoSheet) {
            ConversationInfoView(conversationId: conversationId)
                .environmentObject(authVM)
        }
        .onAppear {
            if let currentUser = authVM.user {
                friendVM.fetchFriends(for: currentUser)
            }
        }
    }
}

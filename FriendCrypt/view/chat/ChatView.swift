//
//  ChatView.swift
//  Friendly
//
//  Created by Nathan Mercier on 07/02/2025.
//

import SwiftUI
import FirebaseFirestore

struct ChatView: View {
    let conversationId: String
    @ObservedObject var chatVM: ChatViewModel
    @State private var messageText = ""
    @ObservedObject var authVM = AuthViewModel.shared
    @StateObject private var convDetailVM: ConversationDetailViewModel
    @StateObject private var userLookupVM = UserLookupViewModel()
    
    @State private var showInfoSheet = false
    
    init(conversationId: String) {
        self.conversationId = conversationId
        self.chatVM = ChatViewModel(conversationId: conversationId)
        _convDetailVM = StateObject(wrappedValue: ConversationDetailViewModel(conversationId: conversationId))
    }
    
    private var navigationTitle: String {
        if let conversation = convDetailVM.conversation {
            let count = conversation.participants.count
            if count == 2 {
                guard let currentUserId = authVM.user?.id else { return "Chat" }
                let friendId = conversation.participants.first { $0 != currentUserId } ?? "Unknown"
                return userLookupVM.username(for: friendId)
            } else if count == 1 {
                return authVM.user?.username ?? "Chat"
            } else {
                return "\(count) people"
            }
        }
        return "Chat"
    }
    
    var body: some View {
        VStack {
            // Use ScrollViewReader to scroll programmatically.
            ScrollViewReader { scrollProxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(chatVM.messages) { message in
                            messageBubble(message)
                                .id(message.id)
                                // When the oldest message appears, load more if available.
                                .onAppear {
                                    if message.id == chatVM.messages.first?.id {
                                        chatVM.loadMoreMessages()
                                    }
                                }
                        }
                    }
                    .padding()
                }
                .onAppear {
                    DispatchQueue.main.async {
                        if let lastMessage = chatVM.messages.last {
                            scrollProxy.scrollTo(lastMessage.id, anchor: .bottom)
                        }
                    }
                }
                .onChange(of: chatVM.messages.count) {
                    if let lastMessage = chatVM.messages.last {
                        withAnimation {
                            scrollProxy.scrollTo(lastMessage.id, anchor: .bottom)
                        }
                    }
                }
            }
            
            // Message input area.
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
            if let _ = authVM.user {
                // If needed, you can fetch additional user data here.
            }
        }
    }
    
    /// A helper to build a single message bubble.
    private func messageBubble(_ message: Message) -> some View {
        let isCurrentUser = (message.senderId == authVM.user?.id)
        let senderName = userLookupVM.username(for: message.senderId)
        let dateText = formattedDate(message.timestamp)
        
        return VStack(alignment: isCurrentUser ? .trailing : .leading, spacing: 4) {
            if !isCurrentUser {
                Text(senderName)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Text(message.text)
                .padding()
                .background(isCurrentUser ? Color.blue : Color.gray.opacity(0.2))
                .foregroundColor(isCurrentUser ? .white : .primary)
                .cornerRadius(12)
            
            Text(dateText)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: isCurrentUser ? .trailing : .leading)
    }
    
    private func formattedDate(_ timestamp: Timestamp) -> String {
        let date = timestamp.dateValue()
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

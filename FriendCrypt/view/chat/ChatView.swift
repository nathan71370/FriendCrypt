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
    @StateObject private var chatVM: ChatViewModel
    @State private var messageText = ""
    @ObservedObject private var authVM = AuthViewModel.shared
    @StateObject private var convDetailVM: ConversationDetailViewModel
    @StateObject private var userLookupVM = UserLookupViewModel()
    
    @State private var showInfoSheet = false
    @State private var initialLoadCompleted = false

    init(conversationId: String) {
        self.conversationId = conversationId
        _chatVM = StateObject(wrappedValue: ChatViewModel(conversationId: conversationId))
        _convDetailVM = StateObject(wrappedValue: ConversationDetailViewModel(conversationId: conversationId))
    }
    
    /// Computes the navigation title based on conversation details.
    private var navigationTitle: String {
        guard let conversation = convDetailVM.conversation else { return "Chat" }
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
    
    var body: some View {
        VStack {
            // Use ScrollViewReader to allow programmatic scrolling.
            ScrollViewReader { scrollProxy in
                ScrollView {
                    VStack(spacing: 12) {
                        ForEach(chatVM.messages) { message in
                            messageBubble(message)
                                .id(message.id) // Tag each message view for scrolling.
                        }
                    }
                    .padding()
                }
                .onChange(of: chatVM.messages) {
                    scrollToBottom(using: scrollProxy)
                }
                .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { notification in
                    if let duration = notification.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double {
                        DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
                            scrollToBottom(using: scrollProxy)
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
    }
    
    /// Scrolls the view to the last message.
    private func scrollToBottom(using proxy: ScrollViewProxy) {
        print("scrolling to bottom")
        guard let lastMessage = chatVM.messages.last else { return }
        if(!initialLoadCompleted) {
            proxy.scrollTo(lastMessage.id, anchor: .bottom)
            initialLoadCompleted = true
            return
        }
        print("with animation")
        DispatchQueue.main.async {
            withAnimation {
                proxy.scrollTo(lastMessage.id, anchor: .bottom)
            }
        }
    }
    
    /// Builds a message bubble.
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
    
    /// Formats a Firestore timestamp into a time string.
    private func formattedDate(_ timestamp: Timestamp) -> String {
        let date = timestamp.dateValue()
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

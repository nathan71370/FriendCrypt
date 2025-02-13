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
    @EnvironmentObject private var conversationVM: ConversationsViewModel
    @EnvironmentObject var friendVM: FriendViewModel

    @State private var showInfoSheet = false
    @State private var initialLoadCompleted = false

    init(conversationId: String) {
        self.conversationId = conversationId
        _chatVM = StateObject(wrappedValue: ChatViewModel(conversationId: conversationId))
    }
    
    private var navigationTitle: String {
        let conversation = conversationVM.conversation(for: self.conversationId)
        if conversation.participants.count == 2 {
            return friendVM.friendName(for: conversation)
        } else if conversation.participants.count == 1 {
            return authVM.user?.username ?? "Chat"
        } else {
            return "\(conversation.participants.count) people"
        }
    }
    
    var body: some View {
        Group {
            chatContent
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
        .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .sheet(isPresented: $showInfoSheet) {
            ConversationInfoView(conversationId: conversationId)
                .environmentObject(authVM)
        }
    }
    
    private var chatContent: some View {
        VStack {
            ScrollViewReader { scrollProxy in
                ScrollView {
                    VStack(spacing: 12) {
                        ForEach(chatVM.messages) { message in
                            messageBubble(message)
                                .id(message.id)
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
    }
    
    private func scrollToBottom(using proxy: ScrollViewProxy) {
        guard let lastMessage = chatVM.messages.last else { return }
        if !initialLoadCompleted {
            proxy.scrollTo(lastMessage.id, anchor: .bottom)
            initialLoadCompleted = true
            return
        }
        DispatchQueue.main.async {
            withAnimation {
                proxy.scrollTo(lastMessage.id, anchor: .bottom)
            }
        }
    }
    
    private func messageBubble(_ message: Message) -> some View {
        let isCurrentUser = (message.senderId == authVM.user?.id)
        let senderName = friendVM.friends[message.senderId]?.username ?? "Loading..."
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

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
        guard let conversation = conversationVM.conversation(for: self.conversationId) else {
            return "Chat"
        }
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
        .onDisappear {
            NavigationRouter.shared.clearCurrentConversation()
        }
    }
    
    private var chatContent: some View {
        VStack {
            ScrollViewReader { scrollProxy in
                ScrollView {
                    VStack(spacing: 12) {
                        // Retrieve the conversation (if available) to know the participant count.
                        let conversation = conversationVM.conversation(for: conversationId)
                        let participantsCount = conversation?.participants.count ?? 2
                        
                        // Use enumerated messages to conditionally insert date headers.
                        ForEach(Array(chatVM.messages.enumerated()), id: \.element.id) { index, message in
                            VStack(spacing: 4) {
                                if shouldShowDateHeader(at: index) {
                                    Text(formattedDateHeader(message.timestamp))
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                MessageBubbleView(
                                    message: message,
                                    isCurrentUser: message.senderId == authVM.user?.id,
                                    senderName: friendVM.friends[message.senderId]?.username ?? "Loading...",
                                    conversationParticipantsCount: participantsCount
                                )
                                .id(message.id)
                            }
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
                Button {
                    let trimmed = messageText.trimmingCharacters(in: .whitespaces)
                    if !trimmed.isEmpty {
                        chatVM.sendMessage(text: trimmed)
                        messageText = ""
                    }
                }
                label: {
                    Image(systemName: "paperplane")
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
    
    /// Determines whether to show a date header before the message at the given index.
    private func shouldShowDateHeader(at index: Int) -> Bool {
        // Always show a header for the very first message.
        if index == 0 { return true }
        
        let currentMessageDate = chatVM.messages[index].timestamp.dateValue()
        let previousMessageDate = chatVM.messages[index - 1].timestamp.dateValue()
        let calendar = Calendar.current
        
        // Show a header if the current message is not on the same day as the previous one.
        return !calendar.isDate(currentMessageDate, inSameDayAs: previousMessageDate)
    }
    
    /// Formats the header date (for example, "Sat Feb 15").
    private func formattedDateHeader(_ timestamp: Timestamp) -> String {
        let date = timestamp.dateValue()
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE MMM dd"
        return formatter.string(from: date)
    }
}

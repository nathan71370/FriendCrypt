import SwiftUI
import FirebaseFirestore

struct ChatView: View {
    let conversationId: String
    
    @StateObject private var chatVM: ChatViewModel
    @ObservedObject private var authVM = AuthViewModel.shared
    @EnvironmentObject private var conversationVM: ConversationsViewModel
    @EnvironmentObject var friendVM: FriendViewModel
    
    @State private var showInfoSheet = false
    @State private var initialLoadCompleted = false
    
    init(conversationId: String, conversationsViewModel: ConversationsViewModel) {
        self.conversationId = conversationId
        _chatVM = StateObject(wrappedValue: ChatViewModel(conversationId: conversationId, conversationsViewModel: conversationsViewModel))
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
    
    // Breaking up the chatContent into smaller components
    private var chatContent: some View {
        VStack {
            messagesScrollView
            messageInputBar
        }
    }
    
    // Extract messages scroll view to a separate component
    private var messagesScrollView: some View {
        ScrollViewReader { scrollProxy in
            ScrollView {
                messagesContent(scrollProxy: scrollProxy)
            }
            .onChange(of: chatVM.messages) {
                scrollToBottom(using: scrollProxy)
            }
            .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { notification in
                handleKeyboardNotification(notification, scrollProxy: scrollProxy)
            }
            .onAppear {
                setupMlsGroup()
            }
        }
    }
    
    // Further breaking down messages content
    private func messagesContent(scrollProxy: ScrollViewProxy) -> some View {
        let conversation = conversationVM.conversation(for: conversationId)
        let participantsCount = conversation?.participants.count ?? 2
        
        return VStack(spacing: 12) {
            ForEach(Array(chatVM.messages.enumerated()), id: \.element.id) { index, message in
                messageRow(index: index, message: message, participantsCount: participantsCount)
                    .id(message.id)
            }
        }
        .padding()
    }
    
    // Extract individual message row
    private func messageRow(index: Int, message: Message, participantsCount: Int) -> some View {
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
                conversationParticipantsCount: participantsCount,
                displayText: chatVM.getDisplayText(for: message)
            )
        }
    }
    
    private var messageInputBar: some View {
        HStack {
            let lineHeight = UIFont.preferredFont(forTextStyle: .body).lineHeight
            GrowingTextEditor(
                text: $chatVM.messageText,
                placeholder: "Message...",
                minHeight: lineHeight * 2,
                maxHeight: lineHeight * 4
            )
            .background(Color(UIColor.secondarySystemBackground))
            .cornerRadius(8)
            
            Button {
                sendMessage()
            } label: {
                Image(systemName: "paperplane")
            }
        }
        .padding()
    }
    
    // Helper methods
    private func sendMessage() {
        let trimmed = chatVM.messageText.trimmingCharacters(in: .whitespaces)
        if !trimmed.isEmpty {
            chatVM.sendMessage()
            chatVM.messageText = ""
        }
    }
    
    private func handleKeyboardNotification(_ notification: Notification, scrollProxy: ScrollViewProxy) {
        if let duration = notification.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double {
            DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
                scrollToBottom(using: scrollProxy)
            }
        }
    }
    
    private func setupMlsGroup() {
        // Check if MLS group exists in the ConversationsViewModel
        if conversationVM.mlsGroup(for: conversationId) == nil {
            // Use the current user's identity to restore the group if needed
            if let userId = authVM.user?.id {
                // Try to load MLS group for this conversation
                conversationVM.tryLoadMlsGroup(for: conversationId, userId: userId)
            }
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
    
    private func shouldShowDateHeader(at index: Int) -> Bool {
        if index == 0 { return true }
        
        let currentMessageDate = chatVM.messages[index].timestamp.dateValue()
        let previousMessageDate = chatVM.messages[index - 1].timestamp.dateValue()
        let calendar = Calendar.current
        return !calendar.isDate(currentMessageDate, inSameDayAs: previousMessageDate)
    }
    
    private func formattedDateHeader(_ timestamp: Timestamp) -> String {
        let date = timestamp.dateValue()
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE MMM dd"
        return formatter.string(from: date)
    }
}

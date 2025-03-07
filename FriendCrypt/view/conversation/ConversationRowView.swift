import SwiftUI
import Firebase

extension String {
    /// Returns a truncated version of the string if it exceeds the specified length.
    /// - Parameters:
    ///   - length: The maximum number of characters to include before truncating.
    ///   - trailing: The string to append after truncation (default is "...")
    /// - Returns: The truncated string with trailing characters if needed.
    func truncated(to length: Int, trailing: String = "...") -> String {
        if self.count > length {
            return String(self.prefix(length)) + trailing
        } else {
            return self
        }
    }
}

extension Date {
    /// Returns a formatted string for the timestamp.
    /// If the date is today, returns "HH:mm", otherwise "dd/MM".
    func formattedTimestamp() -> String {
        let formatter = DateFormatter()
        let calendar = Calendar.current
        if calendar.isDateInToday(self) {
            formatter.dateFormat = "HH:mm"
        } else {
            formatter.dateFormat = "dd/MM"
        }
        return formatter.string(from: self)
    }
}

struct ConversationRowView: View {
    let conversation: Conversation
    
    @EnvironmentObject var conversationsVM: ConversationsViewModel
    @EnvironmentObject var friendVM: FriendViewModel
    @EnvironmentObject var authVM: AuthViewModel
    @State private var lastMessage: Message?
    @State private var displayText: String = "No messages yet"
    
    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                if conversation.participants.count == 2 {
                    Text(friendVM.friendName(for: conversation))
                        .font(.headline)
                } else if conversation.participants.count == 1 {
                    Text(authVM.user?.username ?? "Chat")
                        .font(.headline)
                } else {
                    Text("\(conversation.participants.count) people")
                        .font(.headline)
                }
                Text(displayText.truncated(to: 20))
                    .font(.subheadline)
            }
            Spacer()
            // Display the timestamp if available
            if let timestamp = lastMessage?.timestamp.dateValue() {
                Text(timestamp.formattedTimestamp())
                    .font(.caption)
                    .foregroundColor(.gray)
            }
        }
        .padding(.vertical, 8)
        .onAppear {
            loadLastMessage()
        }
    }
    
    private func loadLastMessage() {
        // If we have a last message ID, fetch that message
        if let lastMessageId = conversation.lastMessageId,
           let convoId = conversation.id {
            // Fetch the message from Firestore
            let db = Firestore.firestore()
            db.collection("conversations").document(convoId)
                .collection("messages").document(lastMessageId)
                .getDocument { snapshot, error in
                    if let error = error {
                        print("Error fetching last message: \(error)")
                        return
                    }
                    
                    if let data = snapshot?.data(),
                       let senderId = data["senderId"] as? String,
                       let encryptedText = data["text"] as? String,
                       let timestamp = data["timestamp"] as? Timestamp {
                        
                        // Create the message
                        let message = Message(
                            id: lastMessageId,
                            senderId: senderId,
                            text: encryptedText,
                            timestamp: timestamp
                        )
                        
                        self.lastMessage = message
                        
                        // Try to get decrypted/cached text
                        if let convoId = conversation.id {
                            if senderId == authVM.user?.id {
                                // For our own messages, check memory cache
                                if let cachedText = conversationsVM.messageRepository.getCachedPlaintext(
                                    messageId: lastMessageId,
                                    conversationId: convoId
                                ) {
                                    self.displayText = cachedText
                                } else {
                                    self.displayText = "[Your message]"
                                }
                            } else {
                                // For others' messages, try to decrypt
                                do {
                                    let decryptedText = try conversationsVM.decryptMessage(
                                        encryptedText: encryptedText,
                                        conversationId: convoId
                                    )
                                    self.displayText = decryptedText
                                } catch {
                                    self.displayText = "[Encrypted message]"
                                }
                            }
                        }
                    }
                }
        }
    }
}

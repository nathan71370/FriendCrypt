import SwiftUI
import FirebaseAuth
import FirebaseFirestore

class ChatViewModel: ObservableObject {
    @Published var messages: [Message] = []
    @Published var messageText: String = ""
    @Published var isLoading: Bool = false
    @Published var error: String? = nil
    
    private let db = Firestore.firestore()
    let conversationId: String
    private var listener: ListenerRegistration?
    
    // Reference to the conversations view model that owns the MLS groups
    private weak var conversationsViewModel: ConversationsViewModel?
    
    init(conversationId: String, conversationsViewModel: ConversationsViewModel) {
        self.conversationId = conversationId
        self.conversationsViewModel = conversationsViewModel
        loadMessages()
    }
    
    // MARK: - Message Loading
    
    private func loadMessages() {
        isLoading = true
        
        // Check if we have an MLS group for this conversation
        guard conversationsViewModel?.mlsGroup(for: conversationId) != nil else {
            error = "Encryption not set up for this conversation yet. Please try again later."
            isLoading = false
            return
        }
        
        let query = db.collection("conversations").document(conversationId)
            .collection("messages")
            .order(by: "timestamp", descending: false)
            .limit(to: 50)
        
        listener = query.addSnapshotListener { [weak self] snapshot, error in
            guard let self = self else { return }
            
            if let error = error {
                self.error = "Error loading messages: \(error.localizedDescription)"
                self.isLoading = false
                return
            }
            
            guard let snapshot = snapshot else {
                self.isLoading = false
                return
            }
            
            // Process messages in order
            var newMessages: [Message] = []
            
            for document in snapshot.documents {
                do {
                    // Get data from the document
                    let data = document.data()
                    let messageId = document.documentID
                    let senderId = data["senderId"] as? String ?? ""
                    let encryptedText = data["text"] as? String ?? ""
                    let timestamp = data["timestamp"] as? Timestamp ?? Timestamp()
                    
                    // Create the message with encrypted text
                    let message = Message(
                        id: messageId,
                        senderId: senderId,
                        text: encryptedText,  // Store encrypted text
                        timestamp: timestamp
                    )
                    
                    newMessages.append(message)
                    
                } catch {
                    print("Error processing message: \(error)")
                    
                    // Add a placeholder for failed messages
                    let errorMessage = Message(
                        id: document.documentID,
                        senderId: document.data()["senderId"] as? String ?? "",
                        text: "[Encryption error: Message cannot be displayed]",
                        timestamp: document.data()["timestamp"] as? Timestamp ?? Timestamp()
                    )
                    newMessages.append(errorMessage)
                }
            }
            
            // Update the messages list
            self.messages = newMessages
            self.isLoading = false
        }
    }
    
    // MARK: - Message Sending
    
    func sendMessage() {
        guard !messageText.isEmpty else { return }
        
        let text = messageText.trimmingCharacters(in: .whitespacesAndNewlines)
        if text.isEmpty { return }
        
        guard let currentUserId = Auth.auth().currentUser?.uid else {
            self.error = "You must be logged in to send messages"
            return
        }
        
        // Clear text field immediately for better UX
        let messageToSend = text
        messageText = ""
        
        // Send via the conversationsViewModel which handles encryption
        conversationsViewModel?.sendMessageWithCache(
            text: messageToSend,
            conversationId: conversationId,
            senderId: currentUserId
        ) { [weak self] result in
            switch result {
            case .success:
                // Message sent successfully
                // The listener will pick up the new message
                break
            case .failure(let error):
                self?.error = "Failed to send message: \(error.localizedDescription)"
                // Restore the message text in case of failure
                DispatchQueue.main.async {
                    self?.messageText = messageToSend
                }
            }
        }
    }
    
    // MARK: - Message Display

    // Get the decrypted or cached text for a message
    func getDisplayText(for message: Message) -> String {
        guard let conversationsViewModel = conversationsViewModel,
              let messageId = message.id else {
            return "[Error: No message context]"
        }
        
        print("Getting display text for message: \(messageId), sender: \(message.senderId)")
        
        // If the message is from the current user, check the memory cache first
        if let currentUserId = Auth.auth().currentUser?.uid,
           message.senderId == currentUserId {
            
            // Try to get from cache
            if let cachedText = conversationsViewModel.messageRepository.getCachedPlaintext(
                messageId: messageId,
                conversationId: conversationId
            ) {
                print("Found cached text for message: \(messageId)")
                return cachedText
            }
            
            print("No cached text found for own message: \(messageId)")
            
            // For debugging, store the original message.text
            let originalText = message.text
            
            // Try to manually add this message to the cache for future reference
            // This helps recover from cases where the cache might have been lost
            do {
                // We can try decryption first, but it will likely fail for own messages
                let decryptedText = try conversationsViewModel.decryptMessage(
                    encryptedText: originalText,
                    conversationId: conversationId
                )
                
                // If successful (unlikely), cache it
                print("Surprisingly, decryption worked for own message. Caching.")
                conversationsViewModel.messageRepository.cachePlaintext(
                    messageId: messageId,
                    conversationId: conversationId,
                    text: decryptedText
                )
                return decryptedText
            } catch {
                // Expected for own messages
                print("Expected: Could not decrypt own message: \(error)")
                return "[Your message]"
            }
        }
        
        // For messages from others, try to decrypt
        do {
            print("Attempting to decrypt other user's message: \(messageId)")
            let decryptedText = try conversationsViewModel.decryptMessage(
                encryptedText: message.text,
                conversationId: conversationId
            )
            
            // Cache successful decryption for future reference
            conversationsViewModel.messageRepository.cachePlaintext(
                messageId: messageId,
                conversationId: conversationId,
                text: decryptedText
            )
            
            return decryptedText
        } catch {
            print("Error decrypting other user's message: \(error)")
            return "[Unable to decrypt message]"
        }
    }
    
    // MARK: - Cleanup
    
    deinit {
        listener?.remove()
    }
}

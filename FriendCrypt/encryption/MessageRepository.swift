import Foundation
import FirebaseFirestore

// Message repository to handle caching and decryption
class MessageRepository {
    private let db = Firestore.firestore()
    
    // In-memory cache for plaintext messages
    private var messageCache: [String: String] = [:]
    
    // Persistent cache for messages
    private let persistentCache = PersistentMessageCache()
    
    // Print debug info
    private func logMessage(_ message: String) {
        print("[MessageRepository] \(message)")
    }
    
    // Get a unique key for the message cache
    private func cacheKey(messageId: String, conversationId: String) -> String {
        return "\(conversationId)_\(messageId)"
    }
    
    // Store plaintext in both memory cache and persistent storage
    func cachePlaintext(messageId: String, conversationId: String, text: String) {
        let key = cacheKey(messageId: messageId, conversationId: conversationId)
        logMessage("Caching message: \(key), text: \(text)")
        
        // Store in memory
        messageCache[key] = text
        
        // Store in persistent cache
        persistentCache.storeMessage(messageId: messageId, conversationId: conversationId, text: text)
    }
    
    // Get cached plaintext if available (checks both memory and persistent storage)
    func getCachedPlaintext(messageId: String, conversationId: String) -> String? {
        let key = cacheKey(messageId: messageId, conversationId: conversationId)
        
        // First check memory cache (faster)
        if let memoryResult = messageCache[key] {
            logMessage("Found message in memory cache: \(key)")
            return memoryResult
        }
        
        // Then check persistent storage
        if let persistentResult = persistentCache.retrieveMessage(messageId: messageId, conversationId: conversationId) {
            logMessage("Found message in persistent cache: \(key)")
            
            // Update memory cache for future lookups
            messageCache[key] = persistentResult
            
            return persistentResult
        }
        
        logMessage("Message not found in any cache: \(key)")
        return nil
    }
    
    // Save a message to Firestore (encrypted only)
    func saveMessage(
        conversationId: String,
        senderId: String,
        encryptedText: String,
        plaintext: String,
        completion: @escaping (Result<Message, Error>) -> Void
    ) {
        let timestamp = Timestamp()
        let data: [String: Any] = [
            "senderId": senderId,
            "text": encryptedText,
            "timestamp": timestamp
        ]
        
        logMessage("Saving message to Firestore for conversation: \(conversationId)")
        
        // Add the message to Firestore
        let messagesRef = db.collection("conversations").document(conversationId).collection("messages")
        messagesRef.addDocument(data: data) { [weak self] error in
            guard let self = self else { return }
            
            if let error = error {
                logMessage("Error saving message: \(error.localizedDescription)")
                completion(.failure(error))
                return
            }
            
            // Find the document we just created using the timestamp
            messagesRef.whereField("timestamp", isEqualTo: timestamp)
                .getDocuments { [weak self] snapshot, error in
                    guard let self = self else { return }
                    
                    if let error = error {
                        logMessage("Error retrieving message ID: \(error.localizedDescription)")
                        completion(.failure(error))
                        return
                    }
                    
                    guard let document = snapshot?.documents.first else {
                        logMessage("No document found after saving")
                        completion(.failure(NSError(domain: "MessageRepository", code: 404, userInfo: [NSLocalizedDescriptionKey: "No document found after saving"])))
                        return
                    }
                    
                    let messageId = document.documentID
                    logMessage("Message saved with ID: \(messageId)")
                    
                    // Store plaintext in both memory and persistent cache
                    self.cachePlaintext(messageId: messageId, conversationId: conversationId, text: plaintext)
                    
                    let message = Message(
                        id: messageId,
                        senderId: senderId,
                        text: encryptedText,
                        timestamp: timestamp
                    )
                    
                    // Update conversation's last message reference
                    self.db.collection("conversations").document(conversationId).updateData([
                        "lastMessageId": messageId,
                        "timestamp": timestamp
                    ])
                    
                    completion(.success(message))
                }
        }
    }
    
    // Get message text, checking caches first
    func getMessageText(
        message: Message,
        conversationId: String,
        currentUserId: String,
        mlsDecryptFunction: (String, String) throws -> String
    ) -> String {
        guard let messageId = message.id else {
            return "[Error: Missing message ID]"
        }
        
        // Check caches first for all messages
        if let cachedText = getCachedPlaintext(messageId: messageId, conversationId: conversationId) {
            return cachedText
        }
        
        // If this is our own message but not in cache
        if message.senderId == currentUserId {
            return "[Your message]" // Show a placeholder for your own messages
        }
        
        // Try to decrypt with MLS for other users' messages
        do {
            let decryptedText = try mlsDecryptFunction(message.text, conversationId)
            
            // Cache the result for future use
            cachePlaintext(messageId: messageId, conversationId: conversationId, text: decryptedText)
            
            return decryptedText
        } catch {
            logMessage("Error decrypting message: \(error)")
            return "[Unable to decrypt]"
        }
    }
    
    // Integrated with ConversationsViewModel for sending messages
    func sendMessage(
        text: String,
        conversationId: String,
        senderId: String,
        mlsGroup: OpenMLS.GroupHandle,
        signer: OpenMLS.SignerHandle,
        completion: @escaping (Result<Message, Error>) -> Void
    ) {
        logMessage("Preparing to send message: \"\(text)\"")
        
        do {
            // Encrypt with MLS
            let encryptedData = try OpenMLS.sendMessage(
                group: mlsGroup,
                message: text,
                signer: signer
            )
            
            let encryptedBase64 = encryptedData.base64EncodedString()
            logMessage("Message encrypted successfully, length: \(encryptedData.count)")
            
            // Save to Firestore, caching plaintext in memory and persistent storage
            saveMessage(
                conversationId: conversationId,
                senderId: senderId,
                encryptedText: encryptedBase64,
                plaintext: text,
                completion: completion
            )
            
        } catch {
            logMessage("Error encrypting message: \(error)")
            completion(.failure(error))
        }
    }
}

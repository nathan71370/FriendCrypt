//
//  ChatViewModel.swift
//  Friendly
//
//  Created by Nathan Mercier on 07/02/2025.
//

import SwiftUI
import FirebaseAuth
import FirebaseFirestore

class ChatViewModel: ObservableObject {
    @Published var messages: [Message] = []
    
    private let db = Firestore.firestore()
    let conversationId: String
    
    // Pagination properties.
    private var lastDocument: DocumentSnapshot?
    private var isLoading = false
    private var hasMoreMessages = true
    private let pageSize = 50

    // Listener for realtime new messages.
    private var realtimeListener: ListenerRegistration?
    
    init(conversationId: String) {
        self.conversationId = conversationId
        loadInitialMessages()
    }
    
    /// Loads the initial (most recent) messages.
    private func loadInitialMessages() {
        guard !isLoading else { return }
        isLoading = true
        
        // Fetch the most recent messages in descending order, then reverse for display.
        db.collection("conversations").document(conversationId)
            .collection("messages")
            .order(by: "timestamp", descending: true)
            .limit(to: pageSize)
            .getDocuments { snapshot, error in
                defer { self.isLoading = false }
                guard let snapshot = snapshot, error == nil else { return }
                
                let fetchedMessages = snapshot.documents.compactMap { try? $0.data(as: Message.self) }
                self.messages = fetchedMessages.reversed()
                
                self.lastDocument = snapshot.documents.last
                self.hasMoreMessages = snapshot.documents.count == self.pageSize
                
                // Start listening for new messages once the initial batch is loaded.
                self.startListeningForNewMessages()
            }
    }
    
    /// Loads more (older) messages when the user scrolls up.
    func loadMoreMessages() {
        guard !isLoading, hasMoreMessages, let lastDocument = lastDocument else { return }
        isLoading = true
        
        db.collection("conversations").document(conversationId)
            .collection("messages")
            .order(by: "timestamp", descending: true)
            .start(afterDocument: lastDocument)
            .limit(to: pageSize)
            .getDocuments { snapshot, error in
                defer { self.isLoading = false }
                guard let snapshot = snapshot, error == nil else { return }
                
                let fetchedMessages = snapshot.documents.compactMap { try? $0.data(as: Message.self) }
                // Prepend older messages (after reversing them) to the array.
                self.messages.insert(contentsOf: fetchedMessages.reversed(), at: 0)
                
                self.lastDocument = snapshot.documents.last
                self.hasMoreMessages = snapshot.documents.count == self.pageSize
            }
    }
    
    /// Starts a realtime listener for new messages that arrive after the last message in the current list.
    private func startListeningForNewMessages() {
        // Determine the timestamp of the newest message currently loaded.
        let lastTimestamp = messages.last?.timestamp ?? Timestamp(date: Date())
        
        realtimeListener = db.collection("conversations").document(conversationId)
            .collection("messages")
            .order(by: "timestamp", descending: false)
            .whereField("timestamp", isGreaterThan: lastTimestamp)
            .addSnapshotListener { snapshot, error in
                guard let snapshot = snapshot, error == nil else { return }
                
                // Filter out documents that might already exist in your messages array.
                let newMessages = snapshot.documents.compactMap { try? $0.data(as: Message.self) }
                // Append and sort (if needed) to ensure proper order.
                self.messages.append(contentsOf: newMessages)
                self.messages.sort { $0.timestamp.dateValue() < $1.timestamp.dateValue() }
            }
    }
    
    /// Sends a new message.
    func sendMessage(text: String) {
        guard let currentUserID = Auth.auth().currentUser?.uid else { return }
        let newMessage = Message(senderId: currentUserID,
                                 text: text,
                                 timestamp: Timestamp())
        do {
            _ = try db.collection("conversations").document(conversationId)
                .collection("messages").addDocument(from: newMessage)
            
            db.collection("conversations").document(conversationId).updateData([
                "lastMessage": text,
                "timestamp": Timestamp()
            ])
        } catch {
            print("Error sending message: \(error.localizedDescription)")
        }
    }
    
    deinit {
        realtimeListener?.remove()
    }
}

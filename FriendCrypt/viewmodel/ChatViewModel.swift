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
    private var realtimeListener: ListenerRegistration?
    
    init(conversationId: String) {
        self.conversationId = conversationId
        loadInitialMessages()
    }
    
    /// Loads the most recent messages and starts a realtime listener.
    private func loadInitialMessages() {
        db.collection("conversations").document(conversationId)
            .collection("messages")
            .order(by: "timestamp", descending: true)
            .limit(to: 50)
            .getDocuments { [weak self] snapshot, error in
                guard let self = self,
                      let snapshot = snapshot,
                      error == nil else { return }
                
                // Reverse the fetched messages for chronological order.
                let fetchedMessages = snapshot.documents.compactMap { try? $0.data(as: Message.self) }
                self.messages = fetchedMessages.reversed()
                
                // Start listening for new messages.
                self.startListeningForNewMessages()
            }
    }
    
    /// Listens for new messages arriving after the current last message.
    private func startListeningForNewMessages() {
        let lastTimestamp = messages.last?.timestamp ?? Timestamp(date: Date())
        realtimeListener = db.collection("conversations").document(conversationId)
            .collection("messages")
            .order(by: "timestamp", descending: false)
            .whereField("timestamp", isGreaterThan: lastTimestamp)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self,
                      let snapshot = snapshot,
                      error == nil else { return }
                
                DispatchQueue.main.async {
                    snapshot.documentChanges.forEach { change in
                        if change.type == .added,
                           let newMessage = try? change.document.data(as: Message.self),
                           !self.messages.contains(where: { $0.id == newMessage.id }) {
                            self.messages.append(newMessage)
                        }
                    }
                }
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
            
            // Optionally update conversation metadata.
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

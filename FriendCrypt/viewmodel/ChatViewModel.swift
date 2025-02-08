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
    private var listener: ListenerRegistration?
    private let db = Firestore.firestore()
    let conversationId: String
    
    init(conversationId: String) {
        self.conversationId = conversationId
        // Listen for messages in the conversation (ordered by timestamp).
        listener = db.collection("conversations").document(conversationId)
            .collection("messages")
            .order(by: "timestamp")
            .addSnapshotListener { snapshot, error in
                if let snapshot = snapshot {
                    self.messages = snapshot.documents.compactMap { document in
                        try? document.data(as: Message.self)
                    }
                }
            }
    }
    
    deinit {
        listener?.remove()
    }
    
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
}

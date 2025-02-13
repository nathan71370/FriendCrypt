//
//  ConversationsViewModel.swift
//  Friendly
//
//  Created by Nathan Mercier on 07/02/2025.
//

import SwiftUI
import FirebaseAuth
import FirebaseFirestore

class ConversationsViewModel: ObservableObject {
    @Published var conversations: [String: Conversation] = [:]
    private var listener: ListenerRegistration?
    
    /// Call this when you have a valid user to start listening for conversations.
    func startListening(for user: ChatUser) {
        listener?.remove()
        listener = nil
        
        guard let currentUserID = user.id else {
            return
        }
        
        print("Starting conversation listener for user: \(currentUserID)")
        let query = Firestore.firestore()
            .collection("conversations")
            .whereField("participants", arrayContains: currentUserID)
            .order(by: "timestamp", descending: true)
        
        listener = query.addSnapshotListener { snapshot, error in
            if let error = error {
                print("Error fetching conversations: \(error.localizedDescription)")
                return
            }
            
            guard let snapshot = snapshot else {
                print("No snapshot received.")
                return
            }
            
            _ = snapshot.documents.compactMap { document -> Conversation? in
                do {
                    let convo = try document.data(as: Conversation.self)
                    self.conversations[convo.id ?? ""] = convo
                    return convo
                } catch {
                    print("Error decoding conversation: \(error.localizedDescription)")
                    return nil
                }
            }
        }
    }
    
    /// Stops the listener.
    func stopListening() {
        listener?.remove()
        listener = nil
    }
    
    /// Removes the current user from a conversation.
    func quitConversation(convo: Conversation, currentUser: ChatUser) {
        guard let convoId = convo.id, let currentUserId = currentUser.id else { return }
        let convoRef = Firestore.firestore().collection("conversations").document(convoId)
        
        convoRef.getDocument { snapshot, error in
            if let error = error {
                print("Error retrieving conversation: \(error.localizedDescription)")
                return
            }
            guard let data = snapshot?.data() else {
                print("No data found for conversation \(convoId)")
                return
            }
            
            var participants = data["participants"] as? [String] ?? []
            participants.removeAll(where: { $0 == currentUserId })
            
            if participants.isEmpty {
                convoRef.delete { error in
                    if let error = error {
                        print("Error deleting conversation: \(error.localizedDescription)")
                    }
                }
            } else {
                convoRef.updateData(["participants": participants]) { error in
                    if let error = error {
                        print("Error updating conversation: \(error.localizedDescription)")
                    }
                }
            }
        }
    }
    
    /// Returns the conversation for a given conversation id.
    func conversation(for convoId: String) -> Conversation {
        return self.conversations[convoId]!
    }
    
    deinit {
        stopListening()
    }
}

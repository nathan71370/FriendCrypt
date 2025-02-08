//
//  ConversationDetailViewModel.swift
//  Friendly
//
//  Created by Nathan Mercier on 08/02/2025.
//

import SwiftUI
import FirebaseFirestore

class ConversationDetailViewModel: ObservableObject {
    @Published var conversation: Conversation?
    private var listener: ListenerRegistration?
    private let db = Firestore.firestore()
    
    init(conversationId: String) {
        listener = db.collection("conversations").document(conversationId)
            .addSnapshotListener { snapshot, error in
                if let error = error {
                    print("Error listening for conversation details: \(error.localizedDescription)")
                    return
                }
                if let snapshot = snapshot, snapshot.exists {
                    do {
                        let convo = try snapshot.data(as: Conversation.self)
                        DispatchQueue.main.async {
                            self.conversation = convo
                        }
                    } catch {
                        print("Error decoding conversation: \(error.localizedDescription)")
                    }
                }
            }
    }
    
    deinit {
        listener?.remove()
    }
}

//
//  AddFriendToConversationView.swift
//  Friendly
//
//  Created by Nathan Mercier on 08/02/2025.
//

import SwiftUI
import FirebaseFirestore

struct AddFriendToConversationView: View {
    let conversationId: String
    @EnvironmentObject var authVM: AuthViewModel
    @State private var availableFriends: [ChatUser] = []
    @Environment(\.dismiss) var dismiss
    private let db = Firestore.firestore()
    
    var body: some View {
        NavigationView {
            List {
                if availableFriends.isEmpty {
                    Text("No available friends to add.")
                        .foregroundColor(.secondary)
                } else {
                    ForEach(availableFriends, id: \.id) { friend in
                        HStack {
                            Text(friend.username)
                            Spacer()
                            Button("Add") {
                                addFriend(friend: friend)
                            }
                            .buttonStyle(BorderlessButtonStyle())
                        }
                    }
                }
            }
            .navigationTitle("Add Friend")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") { dismiss() }
                }
            }
            .onAppear {
                loadAvailableFriends()
            }
        }
    }
    
    func loadAvailableFriends() {
        guard let currentUser = authVM.user, currentUser.id != nil else { return }
        db.collection("conversations").document(conversationId).getDocument { snapshot, error in
            if let error = error {
                print("Error loading conversation: \(error.localizedDescription)")
                return
            }
            guard let data = snapshot?.data(),
                  let participants = data["participants"] as? [String] else { return }
            
            let friendIds = currentUser.friends
            let toAddIds = friendIds.filter { !participants.contains($0) }
            if toAddIds.isEmpty {
                DispatchQueue.main.async {
                    availableFriends = []
                }
                return
            }
            
            db.collection("users")
                .whereField(FieldPath.documentID(), in: toAddIds)
                .getDocuments { snapshot, error in
                    if let error = error {
                        print("Error fetching available friends: \(error.localizedDescription)")
                        return
                    }
                    if let snapshot = snapshot {
                        let friends = snapshot.documents.compactMap { doc in
                            try? doc.data(as: ChatUser.self)
                        }
                        DispatchQueue.main.async {
                            availableFriends = friends
                        }
                    }
                }
        }
    }
    
    func addFriend(friend: ChatUser) {
        guard let friendId = friend.id else { return }
        db.collection("conversations").document(conversationId).updateData([
            "participants": FieldValue.arrayUnion([friendId])
        ]) { error in
            if let error = error {
                print("Error adding friend to conversation: \(error.localizedDescription)")
            } else {
                print("Friend added to conversation.")
                loadAvailableFriends()
            }
        }
    }
}

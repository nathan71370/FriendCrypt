//
//  NewConversationView.swift
//  Friendly
//
//  Created by Nathan Mercier on 07/02/2025.
//
//
//  NewConversationView.swift
//  Friendly
//
//  Created by Nathan Mercier on 07/02/2025.
//

import SwiftUI
import FirebaseAuth
import FirebaseFirestore

struct NewConversationView: View {
    @Environment(\.presentationMode) var presentationMode
    @Binding var isPresented: Bool
    @ObservedObject var authVM = AuthViewModel.shared
    // Use the shared FriendViewModel rather than a new instance.
    @EnvironmentObject var friendVM: FriendViewModel
    @State private var selectedFriendIDs: Set<String> = []
    @State private var errorMessage: String? = nil
    
    private let db = Firestore.firestore()
    
    var body: some View {
        NavigationView {
            VStack {
                if let currentUser = authVM.user {
                    if currentUser.friends.isEmpty {
                        VStack(spacing: 20) {
                            Text("You don't have any friends.")
                                .font(.headline)
                            Text("Please add friends from the Friends tab before starting a conversation.")
                                .multilineTextAlignment(.center)
                                .foregroundColor(.secondary)
                            Button("Go to Friends") {
                                isPresented = false
                            }
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                        }
                        .padding()
                    } else {
                        if friendVM.friends.isEmpty {
                            VStack(spacing: 15) {
                                Text("No friends available.")
                                    .foregroundColor(.secondary)
                                Button("Reload Friends") {
                                    friendVM.fetchFriends(for: currentUser)
                                }
                                .padding()
                                .background(Color.blue.opacity(0.7))
                                .foregroundColor(.white)
                                .cornerRadius(8)
                            }
                            .padding()
                        } else {
                            // Convert dictionary values to an array for display.
                            List(Array(friendVM.friends.values), id: \.id) { friend in
                                Button(action: {
                                    guard let friendID = friend.id else { return }
                                    if selectedFriendIDs.contains(friendID) {
                                        selectedFriendIDs.remove(friendID)
                                    } else {
                                        selectedFriendIDs.insert(friendID)
                                    }
                                }) {
                                    HStack {
                                        Text(friend.username)
                                        Spacer()
                                        if let friendID = friend.id, selectedFriendIDs.contains(friendID) {
                                            Image(systemName: "checkmark")
                                                .foregroundColor(.blue)
                                        }
                                    }
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                    }
                } else {
                    Text("Loading user...")
                        .padding()
                }
                
                if let errorMessage = errorMessage {
                    Text(errorMessage)
                        .foregroundColor(.red)
                        .padding(.top)
                }
                
                Button("Start Conversation") {
                    startConversation()
                }
                .padding()
                .disabled(selectedFriendIDs.isEmpty)
                
                Spacer()
            }
            .navigationTitle("New Conversation")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        isPresented = false
                    }
                }
            }
        }
        .onAppear {
            if let currentUser = authVM.user {
                // This will use the cached friend data if already loaded.
                friendVM.fetchFriends(for: currentUser)
            }
        }
    }
    
    func startConversation() {
        guard let currentUser = Auth.auth().currentUser else { return }
        if selectedFriendIDs.isEmpty {
            errorMessage = "Please select at least one friend."
            return
        }
        errorMessage = nil
        
        let participants = [currentUser.uid] + Array(selectedFriendIDs)
        
        db.collection("conversations")
            .whereField("participants", arrayContains: currentUser.uid)
            .getDocuments { snapshot, error in
                if let error = error {
                    errorMessage = error.localizedDescription
                    return
                }
                if let docs = snapshot?.documents {
                    for doc in docs {
                        let data = doc.data()
                        if let existingParticipants = data["participants"] as? [String] {
                            let setExisting = Set(existingParticipants)
                            let setNew = Set(participants)
                            if setExisting == setNew {
                                isPresented = false
                                return
                            }
                        }
                    }
                }
                let conversationData: [String: Any] = [
                    "participants": participants,
                    "timestamp": Timestamp()
                ]
                db.collection("conversations").addDocument(data: conversationData) { error in
                    if let error = error {
                        errorMessage = error.localizedDescription
                    } else {
                        isPresented = false
                    }
                }
            }
    }
}

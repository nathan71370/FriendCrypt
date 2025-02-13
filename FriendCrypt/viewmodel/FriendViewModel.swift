//
//  FriendViewModel.swift
//  Friendly
//
//  Created by Nathan Mercier on 08/02/2025.
//

import SwiftUI
import FirebaseFirestore

extension Array {
    /// Splits the array into chunks of the specified size.
    func chunked(into size: Int) -> [[Element]] {
        stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}

class FriendViewModel: ObservableObject {
    @ObservedObject var authVM = AuthViewModel.shared
    
    @Published var friends: [String: ChatUser] = [:]
    @Published var isLoading = false
    
    private let db = Firestore.firestore()
    
    func fetchFriends(for user: ChatUser) {
        let friendIDs = user.friends
        if friendIDs.isEmpty {
            DispatchQueue.main.async {
                self.friends = [:]
                self.isLoading = false
            }
            return
        }
        
        isLoading = true
        let chunks = friendIDs.chunked(into: 10)
        var loadedFriends: [String: ChatUser] = self.friends
        let dispatchGroup = DispatchGroup()
        
        for chunk in chunks {
            dispatchGroup.enter()
            db.collection("users")
                .whereField(FieldPath.documentID(), in: chunk)
                .getDocuments { snapshot, error in
                    if let error = error {
                        print("Error fetching friends for chunk: \(error)")
                        dispatchGroup.leave()
                        return
                    }
                    
                    if let documents = snapshot?.documents {
                        for document in documents {
                            do {
                                let friend = try document.data(as: ChatUser.self)
                                if let friendId = friend.id {
                                    loadedFriends[friendId] = friend
                                }
                            } catch {
                                print("Error decoding ChatUser: \(error)")
                            }
                        }
                    }
                    dispatchGroup.leave()
                }
        }
        
        dispatchGroup.notify(queue: .main) {
            self.friends = loadedFriends
            self.isLoading = false
        }
    }
    
    /// Returns the friend’s username for a given conversation.
    func friendName(for convo: Conversation) -> String {
        guard let currentUserId = authVM.user?.id else { return "Unknown" }
        let friendIds = convo.participants.filter { $0 != currentUserId }
        guard let friendId = friendIds.first else { return "Unknown" }
        return self.friends[friendId]?.username ?? "Loading..."
    }
    
    func deleteFriend(friend: ChatUser, currentUser: ChatUser) {
        guard let currentUID = currentUser.id,
              let friendUID = friend.id else { return }
        
        db.collection("users").document(currentUID).updateData([
            "friends": FieldValue.arrayRemove([friendUID])
        ]) { error in
            if let error = error {
                print("Error removing friend from current user's list: \(error.localizedDescription)")
            }
        }
        
        // Optionally, remove currentUID from the friend's friends.
        db.collection("users").document(friendUID).updateData([
            "friends": FieldValue.arrayRemove([currentUID])
        ]) { error in
            if let error = error {
                print("Error removing current user from friend's list: \(error.localizedDescription)")
            }
        }
    }
}

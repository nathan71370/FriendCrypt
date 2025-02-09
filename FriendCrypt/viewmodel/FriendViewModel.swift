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
    
    @Published var friends: [ChatUser] = []
    @Published var isLoading = false
    
    private let db = Firestore.firestore()
    
    /// Fetches friends for a given user by batching friend ID queries.
    func fetchFriends(for user: ChatUser) {
        let friendIDs = user.friends
        if friendIDs.isEmpty {
            DispatchQueue.main.async {
                self.friends = []
                self.isLoading = false
            }
            return
        }
        
        isLoading = true
        let chunks = friendIDs.chunked(into: 10)
        var allFriends: [ChatUser] = []
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
                        do {
                            let friendsChunk = try documents.compactMap { try $0.data(as: ChatUser.self) }
                            allFriends.append(contentsOf: friendsChunk)
                        } catch {
                            print("Error decoding ChatUser: \(error)")
                        }
                    }
                    dispatchGroup.leave()
                }
        }
        
        dispatchGroup.notify(queue: .main) {
            self.friends = allFriends
            self.isLoading = false
        }
    }
    
    /// Deletes a friend by removing the friend UID from the current user's friend list,
    /// and optionally removing the current user's UID from the friend's friend list.
    func deleteFriend(friend: ChatUser, currentUser: ChatUser) {
        guard let currentUID = currentUser.id,
              let friendUID = friend.id else { return }
        
        // Remove friendUID from current user's friends.
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
    
    /// Helper function to return the friend's display name for a conversation.
    func friendName(for convo: Conversation) -> String {
        guard let currentUserId = authVM.user?.id else { return "Unknown" }
        let friendIds = convo.participants.filter { $0 != currentUserId }
        guard let friendId = friendIds.first else { return "Unknown" }
        return self.friends.first(where: { $0.id == friendId })?.username ?? friendId
    }
}

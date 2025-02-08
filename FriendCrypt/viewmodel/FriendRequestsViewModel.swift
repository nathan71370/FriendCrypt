//
//  FriendRequestsViewModel.swift
//  Friendly
//
//  Created by Nathan Mercier on 08/02/2025.
//

import SwiftUI
import FirebaseFirestore

class FriendRequestsViewModel: ObservableObject {
    @Published var friendRequests: [ChatUser] = []
    private let db = Firestore.firestore()
    
    /// Fetches the friend request users from Firestore for the given current user.
    func fetchFriendRequests(for user: ChatUser) {
        // Ensure there are friend requests to process.
        if user.friend_requests.isEmpty {
            DispatchQueue.main.async {
                self.friendRequests = []
            }
            return
        }
        
        // Firestore "in" queries support up to 10 values.
        db.collection("users")
            .whereField(FieldPath.documentID(), in: user.friend_requests)
            .getDocuments { snapshot, error in
                if let error = error {
                    print("Error fetching friend requests: \(error.localizedDescription)")
                    return
                }
                guard let documents = snapshot?.documents else {
                    print("No friend request documents found.")
                    return
                }
                do {
                    // Use snapshot.data(as:) to ensure the id property is set automatically.
                    let requests = try documents.compactMap { try $0.data(as: ChatUser.self) }
                    DispatchQueue.main.async {
                        self.friendRequests = requests
                    }
                } catch {
                    print("Error decoding friend requests: \(error.localizedDescription)")
                }
            }
    }
    
    /// Accept a friend request.
    func acceptRequest(from requestUser: ChatUser, currentUser: ChatUser, completion: @escaping (ChatUser?) -> Void) {
        guard let currentUID = currentUser.id,
              let requestUID = requestUser.id else { return }
        
        let currentUserRef = db.collection("users").document(currentUID)
        
        db.runTransaction({ transaction, errorPointer in
            let currentUserDoc: DocumentSnapshot
            do {
                currentUserDoc = try transaction.getDocument(currentUserRef)
            } catch let error as NSError {
                errorPointer?.pointee = error
                return nil
            }
            
            var currentData = currentUserDoc.data() ?? [:]
            var friendRequests = currentData["friend_requests"] as? [String] ?? []
            var friends = currentData["friends"] as? [String] ?? []
            
            friendRequests.removeAll(where: { $0 == requestUID })
            if !friends.contains(requestUID) {
                friends.append(requestUID)
            }
            
            transaction.updateData([
                "friend_requests": friendRequests,
                "friends": friends
            ], forDocument: currentUserRef)
            
            return nil
        }, completion: { error, _ in
            if let error = error {
                print("Transaction failed while accepting friend request: \(error)")
                completion(nil)
            } else {
                DispatchQueue.main.async {
                    self.friendRequests.removeAll { $0.id == requestUID }
                }
                currentUserRef.getDocument { snapshot, error in
                    if let snapshot = snapshot, snapshot.exists {
                        do {
                            let updatedUser = try snapshot.data(as: ChatUser.self)
                            completion(updatedUser)
                        } catch {
                            print("Error decoding updated user: \(error)")
                            completion(nil)
                        }
                    } else {
                        completion(nil)
                    }
                }
            }
        })
        
        let friendUserRef = db.collection("users").document(requestUID)
        friendUserRef.updateData([
            "friends": FieldValue.arrayUnion([currentUID])
        ]) { error in
            if let error = error {
                print("Error updating the request user's document: \(error.localizedDescription)")
            }
        }
    }
    
    /// Reject a friend request.
    func rejectRequest(from requestUser: ChatUser, currentUser: ChatUser) {
        guard let currentUID = currentUser.id,
              let requestUID = requestUser.id else {
            print("Missing IDs: currentUser.id or requestUser.id is nil")
            return
        }
        
        let currentUserRef = db.collection("users").document(currentUID)
        currentUserRef.updateData([
            "friend_requests": FieldValue.arrayRemove([requestUID])
        ]) { error in
            if let error = error {
                print("Error rejecting friend request: \(error.localizedDescription)")
            } else {
                DispatchQueue.main.async {
                    self.friendRequests.removeAll { $0.id == requestUID }
                }
            }
        }
    }
}

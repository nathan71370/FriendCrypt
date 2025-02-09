//
//  UserLookupViewModel.swift
//  FriendCrypt
//
//  Created by Nathan Mercier on 09/02/2025.
//


import SwiftUI
import FirebaseFirestore

class UserLookupViewModel: ObservableObject {
    @Published private(set) var usersById: [String: ChatUser] = [:]
    private let db = Firestore.firestore()
    
    /// Returns the username for the given userId.
    /// If we don’t have the user cached, fetch from Firestore and return the userId in the meantime.
    func username(for userId: String) -> String {
        if let cachedUser = usersById[userId] {
            return cachedUser.username
        }
        fetchUserIfNeeded(userId: userId)
        return userId
    }
    
    private func fetchUserIfNeeded(userId: String) {
        if usersById.keys.contains(userId) {
            return
        }
        
        db.collection("users").document(userId).getDocument { [weak self] snapshot, error in
            guard let self = self else { return }
            if let error = error {
                print("Error fetching user \(userId): \(error.localizedDescription)")
                return
            }
            guard let snapshot = snapshot, snapshot.exists else {
                print("User document \(userId) does not exist.")
                return
            }
            do {
                let fetchedUser = try snapshot.data(as: ChatUser.self)
                DispatchQueue.main.async {
                    self.usersById[userId] = fetchedUser
                }
            } catch {
                print("Error decoding user \(userId): \(error.localizedDescription)")
            }
        }
    }
}

//
//  DataModel.swift
//  Friendly
//
//  Created by Nathan Mercier on 07/02/2025.
//

import FirebaseFirestore

// A user model (stored in Firestore under "users")
struct ChatUser: Identifiable, Codable {
    @DocumentID var id: String?
    var email: String
    var username: String
    var friend_requests: [String] = []
    var friends: [String] = []
    var fcmToken: String?
}

// A conversation between two (or more) users (stored in "conversations")
struct Conversation: Identifiable, Codable {
    @DocumentID var id: String?
    var participants: [String] 
    var lastMessageId: String?
    var timestamp: Timestamp
}

// A single message in a conversation (stored in the "messages" subcollection)
struct Message: Identifiable, Codable, Equatable {
    @DocumentID var id: String?
    var senderId: String
    var text: String
    var timestamp: Timestamp
}

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
    var keyPackage: String? // Base64 encoded MLS key package
}

// A conversation between two (or more) users (stored in "conversations")
struct Conversation: Identifiable, Codable {
    @DocumentID var id: String?
    var participants: [String] // Array of user IDs
    var lastMessageId: String?
    var timestamp: Timestamp
}

// A single message in a conversation (stored in the "messages" subcollection)
struct Message: Identifiable, Codable, Equatable {
    @DocumentID var id: String?
    var senderId: String
    var text: String // Encrypted message content (base64 encoded)
    var timestamp: Timestamp
    
    static func == (lhs: Message, rhs: Message) -> Bool {
        return lhs.id == rhs.id
    }
}

// Welcome message for MLS groups (stored in "welcomeMessages" subcollection of conversation)
struct WelcomeMessage: Identifiable, Codable {
    @DocumentID var id: String?
    var participantId: String
    var welcomeData: String // Base64 encoded welcome message
    var timestamp: Timestamp
}

// Ratchet tree for MLS groups (stored in "ratchetTrees" subcollection of conversation)
struct RatchetTree: Identifiable, Codable {
    @DocumentID var id: String?
    var treeData: String // Base64 encoded ratchet tree
    var timestamp: Timestamp
}

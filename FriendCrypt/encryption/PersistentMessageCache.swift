//
//  that.swift
//  FriendCrypt
//
//  Created by Nathan Mercier on 07/03/2025.
//


import Foundation

/// A class that provides persistent storage for plaintext messages on the device only
class PersistentMessageCache {
    private let userDefaults = UserDefaults.standard
    private let prefix = "message_plaintext_"
    
    /// Store a message in the device's UserDefaults
    /// - Parameters:
    ///   - messageId: The unique ID of the message
    ///   - conversationId: The conversation ID this message belongs to
    ///   - text: The plaintext content of the message
    func storeMessage(messageId: String, conversationId: String, text: String) {
        let key = makeKey(messageId: messageId, conversationId: conversationId)
        userDefaults.set(text, forKey: key)
        print("Stored message in persistent cache: \(key)")
    }
    
    /// Retrieve a message from the device's UserDefaults
    /// - Parameters:
    ///   - messageId: The unique ID of the message
    ///   - conversationId: The conversation ID this message belongs to
    /// - Returns: The plaintext message if available, nil otherwise
    func retrieveMessage(messageId: String, conversationId: String) -> String? {
        let key = makeKey(messageId: messageId, conversationId: conversationId)
        let result = userDefaults.string(forKey: key)
        print("Retrieved from persistent cache: \(key), found: \(result != nil)")
        return result
    }
    
    /// Delete a message from the device's UserDefaults
    /// - Parameters:
    ///   - messageId: The unique ID of the message
    ///   - conversationId: The conversation ID this message belongs to
    func deleteMessage(messageId: String, conversationId: String) {
        let key = makeKey(messageId: messageId, conversationId: conversationId)
        userDefaults.removeObject(forKey: key)
    }
    
    /// Clear all cached messages
    func clearAll() {
        let allKeys = userDefaults.dictionaryRepresentation().keys
        let messageCacheKeys = allKeys.filter { $0.hasPrefix(prefix) }
        
        for key in messageCacheKeys {
            userDefaults.removeObject(forKey: key)
        }
    }
    
    // Generate a unique key for the message
    private func makeKey(messageId: String, conversationId: String) -> String {
        return "\(prefix)\(conversationId)_\(messageId)"
    }
}
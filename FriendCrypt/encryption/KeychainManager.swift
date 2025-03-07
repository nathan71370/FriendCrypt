//
//  KeychainManager.swift
//  FriendCrypt
//
//  Created by Nathan Mercier on 19/02/2025.
//


import KeychainAccess
import SwiftUI

struct KeychainManager {
    static let shared = KeychainManager()
    let keychain = Keychain(service: "fr.azrodorza.FriendCrypt")

    func saveKeyMaterial(_ data: Data, for conversationId: String) throws {
        try keychain.set(data.base64EncodedString(), key: conversationId)
    }

    func loadKeyMaterial(for conversationId: String) -> Data? {
        if let base64String = try? keychain.get(conversationId),
           let keyData = Data(base64Encoded: base64String) {
            return keyData
        }
        return nil
    }
    
    func deleteKeyMaterial(for conversationId: String) throws {
        try keychain.remove(conversationId)
    }
}

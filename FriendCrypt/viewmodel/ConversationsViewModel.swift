//
//  ConversationsViewModel.swift
//  Friendly
//
//  Created by Nathan Mercier on 07/02/2025.
//  Adapted for custom OpenMLS bridge
//

import SwiftUI
import FirebaseAuth
import FirebaseFirestore

/// A simple error wrapper.
struct MyError: Error {
    let message: String
}

class ConversationsViewModel: ObservableObject {
    @Published var conversations: [String: Conversation] = [:]
    let messageRepository = MessageRepository()
        
    private var listener: ListenerRegistration?
    private let db = Firestore.firestore()
    
    /// Dictionary mapping conversation IDs to their corresponding MLSGroup.
    /// In a real app you might store and restore key material securely.
    var mlsGroups: [String: OpenMLS.GroupHandle] = [:]
    private var groupOwners: [String: String] = [:]
    private var conversationSigners: [String: OpenMLS.SignerHandle] = [:]

    
    // MARK: - Listening for Conversations
    
    func startListening(for user: ChatUser) {
        listener?.remove()
        listener = nil
        conversations = [:]
        
        guard let currentUserID = user.id else { return }
        
        let query = db.collection("conversations")
            .whereField("participants", arrayContains: currentUserID)
            .order(by: "timestamp", descending: true)
        
        listener = query.addSnapshotListener { [weak self] snapshot, error in
            if let error = error {
                print("Error fetching conversations: \(error.localizedDescription)")
                return
            }
            guard let snapshot = snapshot else {
                print("No snapshot received.")
                return
            }
            
            snapshot.documents.forEach { document in
                do {
                    let convo = try document.data(as: Conversation.self)
                    if let convoId = convo.id {
                        self?.conversations[convoId] = convo
                        
                        // Try to load the MLS group if we don't have it yet
                        if self?.mlsGroups[convoId] == nil, let userId = Auth.auth().currentUser?.uid {
                            self?.tryLoadMlsGroup(for: convoId, userId: userId)
                        }
                    }
                } catch {
                    print("Error decoding conversation: \(error.localizedDescription)")
                }
            }
        }
    }
    
    private func logMessage(_ message: String, function: String = #function) {
        let timestamp = Date().timeIntervalSince1970
        let logMessage = "[\(timestamp)] [\(function)] \(message)"
        print(logMessage)
        
        // Also log to file if needed
        if let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
            let fileURL = documentsDirectory.appendingPathComponent("openmls_swift_debug.log")
            
            if let fileHandle = try? FileHandle(forWritingTo: fileURL) {
                fileHandle.seekToEndOfFile()
                if let data = "\(logMessage)\n".data(using: .utf8) {
                    fileHandle.write(data)
                }
                fileHandle.closeFile()
            } else {
                // Create file if it doesn't exist
                try? logMessage.appending("\n").write(to: fileURL, atomically: true, encoding: .utf8)
            }
        }
    }
    
    // MARK: - Creating a New Conversation
    
    /// Creates a new conversation in Firestore.
    func createConversation(creator: ChatUser, participants: [String], completion: @escaping (Result<Conversation, Error>) -> Void) {
        guard let creatorId = creator.id else {
            completion(.failure(MyError(message: "Creator ID is missing")))
            return
        }
        
        let conversationData: [String: Any] = [
            "participants": participants,
            "timestamp": Timestamp()
        ]
        
        var ref: DocumentReference? = nil
        ref = db.collection("conversations").addDocument(data: conversationData) { [weak self] error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let conversationId = ref?.documentID else {
                completion(.failure(MyError(message: "Failed to get conversation ID")))
                return
            }
            
            // Now set up the MLS group
            self?.setupMlsGroup(
                conversationId: conversationId,
                creatorId: creatorId,
                participants: participants,
                completion: completion
            )
        }
    }
    
    func createGroup(for conversationId: String, userId: String) {
        logMessage("Creating MLS group for conversation: \(conversationId), user: \(userId)")
        
        do {
            // Use consistent credentials
            let (credential, signer) = try OpenMLS.getOrCreateCredential(userId: userId)
            
            // Create the group
            let mlsGroup = try OpenMLS.createGroup(signer: signer, credential: credential)
            
            // Store the group and its owner
            mlsGroups[conversationId] = mlsGroup
            groupOwners[conversationId] = userId
            
            logMessage("MLS group created successfully")
        } catch {
            logMessage("Error creating MLS group: \(error)")
        }
    }
    
    func setupMlsGroup(
        conversationId: String,
        creatorId: String,
        participants: [String],
        completion: @escaping (Result<Conversation, Error>) -> Void
    ) {
        do {
            // Generate the creator's credentials
            logMessage("Generating credentials for creator: \(creatorId)")
            let (credential, signer) = try OpenMLS.generateCredential(identity: creatorId)
            
            // Create a new MLS group
            logMessage("Creating MLS group")
            let mlsGroup = try OpenMLS.createGroup(signer: signer, credential: credential)
            
            // Store the MLS group and signer
            self.mlsGroups[conversationId] = mlsGroup
            self.conversationSigners[conversationId] = signer
            
            // Add other participants to the group
            let participantsToAdd = participants.filter { $0 != creatorId }
            
            if participantsToAdd.isEmpty {
                // No other participants to add, we're done
                let conversation = Conversation(
                    id: conversationId,
                    participants: participants,
                    lastMessageId: nil,
                    timestamp: Timestamp()
                )
                
                self.conversations[conversationId] = conversation
                
                // Export and store the ratchet tree for future use
                storeRatchetTree(conversationId: conversationId, mlsGroup: mlsGroup)
                
                // Clean up resources
                //OpenMLS.freeCredential(credential)
                //OpenMLS.freeSigner(signer)
                
                completion(.success(conversation))
                return
            }
            
            // Fetch and add participants one by one
            let remainingParticipants = participantsToAdd
            self.addNextParticipant(
                remainingParticipants: remainingParticipants,
                conversationId: conversationId,
                mlsGroup: mlsGroup,
                signer: signer,
                onComplete: { [weak self] error in
                    if let error = error {
                        // Clean up resources
                        //OpenMLS.freeCredential(credential)
                        //OpenMLS.freeSigner(signer)
                        completion(.failure(error))
                        return
                    }
                    
                    // Export and store the ratchet tree for future use
                    self?.storeRatchetTree(conversationId: conversationId, mlsGroup: mlsGroup)
                    
                    // Clean up resources
                    //OpenMLS.freeCredential(credential)
                    //OpenMLS.freeSigner(signer)
                    
                    // Create the conversation object
                    let conversation = Conversation(
                        id: conversationId,
                        participants: participants,
                        lastMessageId: nil,
                        timestamp: Timestamp()
                    )
                    
                    self?.conversations[conversationId] = conversation
                    completion(.success(conversation))
                }
            )
        } catch {
            completion(.failure(error))
        }
    }
    
    private func addNextParticipant(
        remainingParticipants: [String],
        conversationId: String,
        mlsGroup: OpenMLS.GroupHandle,
        signer: OpenMLS.SignerHandle,
        onComplete: @escaping (Error?) -> Void
    ) {
        guard let participantId = remainingParticipants.first else {
            // No more participants to add
            onComplete(nil)
            return
        }
        
        var newRemainingParticipants = remainingParticipants
        newRemainingParticipants.removeFirst()
        
        // Fetch participant's key package
        fetchParticipantKeyPackage(participantId) { [weak self] result in
            switch result {
            case .success(let keyPackage):
                do {
                    // Add participant to the group
                    let welcome = try OpenMLS.addMembers(
                        group: mlsGroup,
                        signer: signer,
                        keyPackages: [keyPackage]
                    )
                    
                    // Merge the pending commit
                    try OpenMLS.mergePendingCommit(group: mlsGroup)
                    
                    // Store welcome message for the participant
                    try self?.storeWelcomeMessage(
                        conversationId: conversationId,
                        participantId: participantId,
                        welcome: welcome
                    )
                    
                    // Clean up resources
                    //OpenMLS.freeKeyPackage(keyPackage)
                    //OpenMLS.freeWelcome(welcome)
                    
                    // Process next participant
                    self?.addNextParticipant(
                        remainingParticipants: newRemainingParticipants,
                        conversationId: conversationId,
                        mlsGroup: mlsGroup,
                        signer: signer,
                        onComplete: onComplete
                    )
                    
                } catch {
                    // Clean up resources
                    //OpenMLS.freeKeyPackage(keyPackage)
                    onComplete(error)
                }
                
            case .failure(let error):
                // Handle missing key package
                print("Warning: Could not fetch key package for user \(participantId): \(error.localizedDescription)")
                
                // Continue with other participants
                self?.addNextParticipant(
                    remainingParticipants: newRemainingParticipants,
                    conversationId: conversationId,
                    mlsGroup: mlsGroup,
                    signer: signer,
                    onComplete: onComplete
                )
            }
        }
    }
    
    private func fetchParticipantKeyPackage(_ participantId: String, completion: @escaping (Result<OpenMLS.KeyPackageHandle, Error>) -> Void) {
        db.collection("users").document(participantId).getDocument { snapshot, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let data = snapshot?.data(),
                  let keyPackageBase64 = data["keyPackage"] as? String,
                  let keyPackageData = Data(base64Encoded: keyPackageBase64) else {
                completion(.failure(MyError(message: "No key package found for user \(participantId)")))
                return
            }
            
            do {
                // Deserialize the key package
                let keyPackage = try OpenMLS.deserializeKeyPackage(data: keyPackageData)
                completion(.success(keyPackage))
            } catch {
                completion(.failure(error))
            }
        }
    }
    
    // MARK: - Welcome Message Management
    
    private func storeWelcomeMessage(
        conversationId: String,
        participantId: String,
        welcome: OpenMLS.WelcomeHandle
    ) throws {
        // Serialize the welcome message
        let welcomeData = try OpenMLS.serializeWelcome(welcome: welcome)
        let welcomeBase64 = welcomeData.base64EncodedString()
        
        // Store as subcollection of conversation
        db.collection("conversations").document(conversationId)
            .collection("welcomeMessages").document(participantId)
            .setData([
                "participantId": participantId,
                "welcomeData": welcomeBase64,
                "timestamp": Timestamp()
            ]) { error in
                if let error = error {
                    print("Error storing welcome message: \(error.localizedDescription)")
                }
            }
    }
    
    private func fetchWelcomeMessage(conversationId: String, userId: String, completion: @escaping (Data?) -> Void) {
        db.collection("conversations").document(conversationId)
            .collection("welcomeMessages").document(userId)
            .getDocument { snapshot, error in
                if let error = error {
                    print("Error fetching welcome message: \(error.localizedDescription)")
                    completion(nil)
                    return
                }
                
                guard let data = snapshot?.data(),
                      let welcomeBase64 = data["welcomeData"] as? String,
                      let welcomeData = Data(base64Encoded: welcomeBase64) else {
                    completion(nil)
                    return
                }
                
                completion(welcomeData)
            }
    }
    
    // MARK: - Ratchet Tree Management
    
    private func storeRatchetTree(conversationId: String, mlsGroup: OpenMLS.GroupHandle) {
        do {
            let ratchetTreeData = try OpenMLS.exportRatchetTree(group: mlsGroup)
            let treeBase64 = ratchetTreeData.base64EncodedString()
            
            // Store as subcollection of conversation
            db.collection("conversations").document(conversationId)
                .collection("ratchetTrees").document("latest")
                .setData([
                    "treeData": treeBase64,
                    "timestamp": Timestamp()
                ]) { error in
                    if let error = error {
                        print("Error storing ratchet tree: \(error.localizedDescription)")
                    }
                }
        } catch {
            print("Error exporting ratchet tree: \(error.localizedDescription)")
        }
    }
    
    private func fetchRatchetTree(conversationId: String, completion: @escaping (Data?) -> Void) {
        db.collection("conversations").document(conversationId)
            .collection("ratchetTrees").document("latest")
            .getDocument { snapshot, error in
                if let error = error {
                    print("Error fetching ratchet tree: \(error.localizedDescription)")
                    completion(nil)
                    return
                }
                
                guard let data = snapshot?.data(),
                      let treeBase64 = data["treeData"] as? String,
                      let treeData = Data(base64Encoded: treeBase64) else {
                    completion(nil)
                    return
                }
                
                completion(treeData)
            }
    }
    
    // MARK: - MLS Group Management
    
    /// Try to load or create the MLS group for a conversation
    func tryLoadMlsGroup(for conversationId: String, userId: String) {
        logMessage("Trying to load MLS group for conversation: \(conversationId), user: \(userId)")
        
        // Check if we already have this group
        if let _ = mlsGroups[conversationId] {
            logMessage("MLS group already loaded")
            return
        }
        
        // Check if user is the creator
        if let conversation = conversations[conversationId], conversation.participants.first == userId {
            logMessage("User is the creator, creating new group")
            createGroup(for: conversationId, userId: userId)
            return
        }
        
        // Otherwise look for a welcome message
        fetchWelcomeMessage(conversationId: conversationId, userId: userId) { [weak self] welcomeData in
            if let welcomeData = welcomeData {
                self?.logMessage("Found welcome message, joining group")
                self?.joinGroup(conversationId: conversationId, welcomeData: welcomeData)
            } else {
                self?.logMessage("No welcome message found")
            }
        }
    }
    
    private func joinGroup(conversationId: String, welcomeData: Data) {
        logMessage("Starting to join MLS group for conversation: \(conversationId)")
        
        // Fetch the ratchet tree
        fetchRatchetTree(conversationId: conversationId) { [weak self] ratchetTreeData in
            guard let self = self else { return }
            
            do {
                // Get user ID from Auth
                guard let userId = Auth.auth().currentUser?.uid else {
                    self.logMessage("No current user ID available")
                    return
                }
                
                // Generate credentials for the current user
                self.logMessage("Generating credentials for user: \(userId)")
                let (_, signer) = try OpenMLS.generateCredential(identity: userId)
                
                // Deserialize welcome message
                self.logMessage("Deserializing welcome message")
                let welcome = try OpenMLS.deserializeWelcome(data: welcomeData)
                
                // Create staged welcome
                self.logMessage("Creating staged welcome")
                let stagedWelcome = try OpenMLS.createStagedWelcome(
                    welcome: welcome,
                    ratchetTreeData: ratchetTreeData
                )
                
                // Complete group join, passing the signer to store with the group
                self.logMessage("Completing group join")
                let mlsGroup = try OpenMLS.completeGroupJoin(
                    stagedWelcome: stagedWelcome,
                    signer: signer
                )
                
                // Store MLS group and signer
                self.mlsGroups[conversationId] = mlsGroup
                self.conversationSigners[conversationId] = signer
                
                self.logMessage("Successfully joined MLS group")
                
            } catch {
                self.logMessage("Error joining MLS group: \(error)")
            }
        }
    }
    
    // MARK: - Quit Conversation
    
    func quitConversation(convo: Conversation, currentUser: ChatUser) {
        guard let convoId = convo.id, let currentUserId = currentUser.id else { return }
        let convoRef = db.collection("conversations").document(convoId)
        
        convoRef.getDocument { [weak self] snapshot, error in
            if let error = error {
                print("Error retrieving conversation: \(error.localizedDescription)")
                return
            }
            guard let data = snapshot?.data() else {
                print("No data found for conversation \(convoId)")
                return
            }
            
            var participants = data["participants"] as? [String] ?? []
            participants.removeAll(where: { $0 == currentUserId })
            
            if participants.isEmpty {
                convoRef.delete { error in
                    if let error = error {
                        print("Error deleting conversation: \(error.localizedDescription)")
                    } else {
                        // Remove MLS group when the conversation is deleted
                        self?.cleanupConversation(conversationId: convoId)
                    }
                }
            } else {
                convoRef.updateData(["participants": participants]) { error in
                    if let error = error {
                        print("Error updating conversation: \(error.localizedDescription)")
                    }
                }
            }
        }
    }
    
    // MARK: - Message Sending and Encryption
    
    /// Send an encrypted message to a conversation
    func sendMessageWithCache(
            text: String,
            conversationId: String,
            senderId: String,
            completion: @escaping (Result<Message, Error>) -> Void
        ) {
            guard let mlsGroup = mlsGroups[conversationId] else {
                completion(.failure(MyError(message: "No MLS group for this conversation")))
                return
            }
            
            do {
                // Get or create signer
                let signerToUse: OpenMLS.SignerHandle
                if let existingSigner = conversationSigners[conversationId] {
                    signerToUse = existingSigner
                } else {
                    let (_, newSigner) = try OpenMLS.generateCredential(identity: senderId)
                    conversationSigners[conversationId] = newSigner
                    signerToUse = newSigner
                }
                
                // Use the repository to send and cache
                messageRepository.sendMessage(
                    text: text,
                    conversationId: conversationId,
                    senderId: senderId,
                    mlsGroup: mlsGroup,
                    signer: signerToUse,
                    completion: completion
                )
                
            } catch {
                completion(.failure(error))
            }
        }
        
        // Helper to get message text
        func getCachedMessageText(message: Message, conversationId: String) -> String {
            guard let currentUserId = Auth.auth().currentUser?.uid else {
                return "[Error: No current user]"
            }
            
            return messageRepository.getMessageText(
                message: message,
                conversationId: conversationId,
                currentUserId: currentUserId,
                mlsDecryptFunction: decryptMessage
            )
        }

    /// Decrypt a message using the MLS group
    func decryptMessage(encryptedText: String, conversationId: String) throws -> String {
        logMessage("Starting to decrypt message for conversation: \(conversationId)")
        
        guard let mlsGroup = mlsGroups[conversationId] else {
            let error = MyError(message: "Missing MLS group for conversation: \(conversationId)")
            logMessage("Error: \(error.message)")
            throw error
        }
        
        guard let encryptedData = Data(base64Encoded: encryptedText) else {
            let error = MyError(message: "Invalid base64 encoded message")
            logMessage("Error: \(error.message)")
            throw error
        }
        
        logMessage("Successfully decoded base64, encrypted data size: \(encryptedData.count) bytes")
        
        // Display hex preview of the encrypted data
        if encryptedData.count > 0 {
            let previewSize = min(16, encryptedData.count)
            let hexPreview = encryptedData.prefix(previewSize).map { String(format: "%02x", $0) }.joined(separator: " ")
            logMessage("Encrypted data preview: \(hexPreview)")
        }
        
        // Add more details about the MLS group
        logMessage("MLS group reference: \(mlsGroup) for conversation: \(conversationId)")
        
        // Try to decrypt
        do {
            logMessage("Calling OpenMLS.decryptMessage")
            let decryptedData = try OpenMLS.decryptMessage(
                group: mlsGroup,
                messageData: encryptedData
            )
            
            logMessage("Message decrypted successfully, decrypted size: \(decryptedData.count) bytes")
            
            // Try to convert the decrypted data to a string
            guard let decryptedString = String(data: decryptedData, encoding: .utf8) else {
                let error = MyError(message: "Could not decode decrypted message as UTF-8")
                logMessage("Error: \(error.message)")
                throw error
            }
            
            logMessage("Successfully decoded message text: \(decryptedString)")
            return decryptedString
        } catch {
            logMessage("Error during decryption: \(error)")
            
            // Add more details about the error
            let nsError = error as NSError  // No need for optional casting
            logMessage("Error details - domain: \(nsError.domain), code: \(nsError.code)")
            if let errorMessage = nsError.userInfo["NSLocalizedDescription"] as? String {
                logMessage("Error description: \(errorMessage)")
            }
                    
            
            throw error
        }
    }
    
    /// When you no longer need the MLS group, free its memory.
    func cleanupConversation(conversationId: String) {
        if let mlsGroup = mlsGroups[conversationId] {
            //OpenMLS.freeGroup(mlsGroup)
            mlsGroups.removeValue(forKey: conversationId)
        }
    }
    
    // MARK: - Helpers
    
    func conversation(for convoId: String) -> Conversation? {
        return conversations[convoId]
    }
    
    func mlsGroup(for convoId: String) -> OpenMLS.GroupHandle? {
        return mlsGroups[convoId]
    }
    
    var sortedConversations: [Conversation] {
        return conversations.values.sorted {
            $0.timestamp.dateValue() > $1.timestamp.dateValue()
        }
    }
    
    deinit {
        // Clean up all MLS groups when the view model is deallocated
        for (conversationId, _) in mlsGroups {
            cleanupConversation(conversationId: conversationId)
        }
        
        listener?.remove()
    }
}

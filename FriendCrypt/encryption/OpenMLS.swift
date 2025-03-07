import Foundation

public class OpenMLS {
    
    // Store for consistent identities across MLS operations
    private static var groupSigners: [ObjectIdentifier: SignerHandle] = [:]

    // Store the signer for a group
    static func storeSignerForGroup(_ group: GroupHandle, signer: SignerHandle) {
        let groupId = ObjectIdentifier(group)
        print("[OpenMLS] Storing signer for group: \(groupId)")
        groupSigners[groupId] = signer
    }

    // Get the stored signer for a group, if available
    static func getSignerForGroup(_ group: GroupHandle) -> SignerHandle? {
        let groupId = ObjectIdentifier(group)
        let signer = groupSigners[groupId]
        if signer != nil {
            print("[OpenMLS] Retrieved existing signer for group: \(groupId)")
        } else {
            print("[OpenMLS] No signer found for group: \(groupId)")
        }
        return signer
    }
    
    // Stored credentials
    private static var userCredentials: [String: (credential: CredentialHandle, signer: SignerHandle)] = [:]

    // Get or create credentials for a user, ensuring the same credentials are used consistently
    static func getOrCreateCredential(userId: String) throws -> (credential: CredentialHandle, signer: SignerHandle) {
        print("[OpenMLS] Getting or creating credential for user: \(userId)")
        
        // Check if we already have credentials for this user
        if let cached = userCredentials[userId] {
            print("[OpenMLS] Using cached credentials for user: \(userId)")
            return cached
        }
        
        // Generate new credentials
        print("[OpenMLS] Generating new credentials for user: \(userId)")
        let (credential, signer) = try generateCredential(identity: userId)
        
        // Cache them for future use
        userCredentials[userId] = (credential, signer)
        print("[OpenMLS] Cached credentials for user: \(userId)")
        
        return (credential, signer)
    }
    
    // Error handling
    public enum OpenMLSError: Error {
        case ffiError(String)
        case nullPointer
    }
    
    // MARK: - Types
    
    // Handle classes for opaque C types
    public class GroupHandle {
        fileprivate var ptr: UnsafeMutablePointer<GroupContext>
        
        fileprivate init(ptr: UnsafeMutablePointer<GroupContext>) {
            self.ptr = ptr
        }
        
        deinit {
            // Memory management is handled by explicit free methods
        }
    }
    
    public class SignerHandle {
        fileprivate var ptr: UnsafeMutablePointer<SignerContext>
        
        fileprivate init(ptr: UnsafeMutablePointer<SignerContext>) {
            self.ptr = ptr
        }
        
        deinit {
            // Memory management is handled by explicit free methods
        }
    }
    
    public class CredentialHandle {
        fileprivate var ptr: UnsafeMutablePointer<CredentialContext>
        
        fileprivate init(ptr: UnsafeMutablePointer<CredentialContext>) {
            self.ptr = ptr
        }
        
        deinit {
            // Memory management is handled by explicit free methods
        }
    }
    
    public class KeyPackageHandle {
        fileprivate var ptr: UnsafeMutablePointer<KeyPackageContext>
        
        fileprivate init(ptr: UnsafeMutablePointer<KeyPackageContext>) {
            self.ptr = ptr
        }
        
        deinit {
            // Memory management is handled by explicit free methods
        }
    }
    
    public class WelcomeHandle {
        fileprivate var ptr: UnsafeMutablePointer<WelcomeContext>
        
        fileprivate init(ptr: UnsafeMutablePointer<WelcomeContext>) {
            self.ptr = ptr
        }
        
        deinit {
            // Memory management is handled by explicit free methods
        }
    }
    
    public class StagedWelcomeHandle {
        fileprivate var ptr: UnsafeMutablePointer<StagedWelcomeContext>
        
        fileprivate init(ptr: UnsafeMutablePointer<StagedWelcomeContext>) {
            self.ptr = ptr
        }
        
        deinit {
            // Memory management is handled by explicit free methods
        }
    }
    
    // MARK: - Public API
    
    /// Get the default ciphersuite
    public static func getDefaultCiphersuite() -> UInt32 {
        return get_default_ciphersuite()
    }
    
    /// Generate credential with key
    public static func generateCredential(identity: String, ciphersuiteId: UInt32 = 0) throws -> (credential: CredentialHandle, signer: SignerHandle) {
    
        // Allocate memory for contexts
        let credentialPtr = UnsafeMutablePointer<CredentialContext>.allocate(capacity: 1)
        let signerPtr = UnsafeMutablePointer<SignerContext>.allocate(capacity: 1)
        
        let result = identity.withCString { identityPtr in
            generate_credential(identityPtr, credentialPtr, signerPtr)
        }
        
        if !result.success {
            // Clean up if there's an error
            credentialPtr.deallocate()
            signerPtr.deallocate()
            
            if let errorMessagePtr = result.error_message {
                let errorMessage = String(cString: errorMessagePtr)
                free_error_message(result)
                throw OpenMLSError.ffiError(errorMessage)
            } else {
                throw OpenMLSError.ffiError("Unknown FFI error")
            }
        }
        
        let credentialHandle = CredentialHandle(ptr: credentialPtr)
        let signerHandle = SignerHandle(ptr: signerPtr)
        
        return (credentialHandle, signerHandle)
    }
    
    /// Generate key package
    public static func generateKeyPackage(ciphersuiteId: UInt32 = 0,
                                     signer: SignerHandle,
                                     credential: CredentialHandle) throws -> KeyPackageHandle {
        let keyPackagePtr = UnsafeMutablePointer<KeyPackageContext>.allocate(capacity: 1)
        
        let result = generate_key_package(signer.ptr, credential.ptr, keyPackagePtr)
        
        if !result.success {
            keyPackagePtr.deallocate()
            
            if let errorMessagePtr = result.error_message {
                let errorMessage = String(cString: errorMessagePtr)
                free_error_message(result)
                throw OpenMLSError.ffiError(errorMessage)
            } else {
                throw OpenMLSError.ffiError("Unknown FFI error")
            }
        }
        
        return KeyPackageHandle(ptr: keyPackagePtr)
    }
    
    /// Create a new MLS group
    public static func createGroup(
        signer: SignerHandle,
        credential: CredentialHandle
    ) throws -> GroupHandle {
        print("[OpenMLS] Creating MLS group")
        let groupPtr = UnsafeMutablePointer<GroupContext>.allocate(capacity: 1)
        
        let result = create_mls_group(signer.ptr, credential.ptr, groupPtr)
        
        if !result.success {
            groupPtr.deallocate()
            
            if let errorMessagePtr = result.error_message {
                let errorMessage = String(cString: errorMessagePtr)
                print("[OpenMLS] Error creating group: \(errorMessage)")
                free_error_message(result)
                throw OpenMLSError.ffiError(errorMessage)
            } else {
                print("[OpenMLS] Unknown error creating group")
                throw OpenMLSError.ffiError("Unknown FFI error")
            }
        }
        
        let groupHandle = GroupHandle(ptr: groupPtr)
        
        // Store the signer with the group
        storeSignerForGroup(groupHandle, signer: signer)
        print("[OpenMLS] Group created successfully and signer stored")
        
        return groupHandle
    }
    
    /// Add members to a group
    public static func addMembers(group: GroupHandle,
                             signer: SignerHandle,
                             keyPackages: [KeyPackageHandle]) throws -> WelcomeHandle {
        let welcomePtr = UnsafeMutablePointer<WelcomeContext>.allocate(capacity: 1)
        
        // Create array of pointers to key package contexts
        let keyPackagesPtrArray = UnsafeMutablePointer<UnsafePointer<KeyPackageContext>?>.allocate(capacity: keyPackages.count)
        
        // Set up the array of key package pointers
        for (index, keyPackage) in keyPackages.enumerated() {
            keyPackagesPtrArray[index] = UnsafePointer(keyPackage.ptr)
        }
        
        let result = add_members(group.ptr, signer.ptr, keyPackagesPtrArray, keyPackages.count, welcomePtr)
        
        // Clean up temporary array
        keyPackagesPtrArray.deallocate()
        
        if !result.success {
            welcomePtr.deallocate()
            
            if let errorMessagePtr = result.error_message {
                let errorMessage = String(cString: errorMessagePtr)
                free_error_message(result)
                throw OpenMLSError.ffiError(errorMessage)
            } else {
                throw OpenMLSError.ffiError("Unknown FFI error")
            }
        }
        
        return WelcomeHandle(ptr: welcomePtr)
    }
    
    /// Merge pending commit
    public static func mergePendingCommit(group: GroupHandle) throws {
        let result = merge_pending_commit(group.ptr)
        
        if !result.success {
            if let errorMessagePtr = result.error_message {
                let errorMessage = String(cString: errorMessagePtr)
                free_error_message(result)
                throw OpenMLSError.ffiError(errorMessage)
            } else {
                throw OpenMLSError.ffiError("Unknown FFI error")
            }
        }
    }
    
    /// Export ratchet tree
    public static func exportRatchetTree(group: GroupHandle) throws -> Data {
        var dataPtr: UnsafeMutablePointer<UInt8>?
        var dataLen: Int = 0
        
        let result = export_ratchet_tree(group.ptr, &dataPtr, &dataLen)
        
        if !result.success {
            if let errorMessagePtr = result.error_message {
                let errorMessage = String(cString: errorMessagePtr)
                free_error_message(result)
                throw OpenMLSError.ffiError(errorMessage)
            } else {
                throw OpenMLSError.ffiError("Unknown FFI error")
            }
        }
        
        guard let ptr = dataPtr else {
            throw OpenMLSError.nullPointer
        }
        
        let data = Data(bytes: ptr, count: dataLen)
        free_buffer(ptr, dataLen)
        
        return data
    }
    
    /// Serialize welcome message
    public static func serializeWelcome(welcome: WelcomeHandle) throws -> Data {
        var dataPtr: UnsafeMutablePointer<UInt8>?
        var dataLen: Int = 0
        
        let result = serialize_welcome(welcome.ptr, &dataPtr, &dataLen)
        
        if !result.success {
            if let errorMessagePtr = result.error_message {
                let errorMessage = String(cString: errorMessagePtr)
                free_error_message(result)
                throw OpenMLSError.ffiError(errorMessage)
            } else {
                throw OpenMLSError.ffiError("Unknown FFI error")
            }
        }
        
        guard let ptr = dataPtr else {
            throw OpenMLSError.nullPointer
        }
        
        let data = Data(bytes: ptr, count: dataLen)
        free_buffer(ptr, dataLen)
        
        return data
    }
    
    /// Deserialize welcome message
    public static func deserializeWelcome(data: Data) throws -> WelcomeHandle {
        let welcomePtr = UnsafeMutablePointer<WelcomeContext>.allocate(capacity: 1)
        
        let result = data.withUnsafeBytes { dataPtr in
            deserialize_welcome(
                dataPtr.baseAddress?.assumingMemoryBound(to: UInt8.self),
                data.count,
                welcomePtr
            )
        }
        
        if !result.success {
            welcomePtr.deallocate()
            
            if let errorMessagePtr = result.error_message {
                let errorMessage = String(cString: errorMessagePtr)
                free_error_message(result)
                throw OpenMLSError.ffiError(errorMessage)
            } else {
                throw OpenMLSError.ffiError("Unknown FFI error")
            }
        }
        
        return WelcomeHandle(ptr: welcomePtr)
    }
    
    /// Create staged welcome
    public static func createStagedWelcome(welcome: WelcomeHandle, ratchetTreeData: Data?) throws -> StagedWelcomeHandle {
        let stagedWelcomePtr = UnsafeMutablePointer<StagedWelcomeContext>.allocate(capacity: 1)
        
        let result: FfiResult
        
        if let treeData = ratchetTreeData {
            result = treeData.withUnsafeBytes { dataPtr in
                create_staged_welcome(
                    welcome.ptr,
                    dataPtr.baseAddress?.assumingMemoryBound(to: UInt8.self),
                    treeData.count,
                    stagedWelcomePtr
                )
            }
        } else {
            result = create_staged_welcome(
                welcome.ptr,
                nil,
                0,
                stagedWelcomePtr
            )
        }
        
        if !result.success {
            stagedWelcomePtr.deallocate()
            
            if let errorMessagePtr = result.error_message {
                let errorMessage = String(cString: errorMessagePtr)
                free_error_message(result)
                throw OpenMLSError.ffiError(errorMessage)
            } else {
                throw OpenMLSError.ffiError("Unknown FFI error")
            }
        }
        
        return StagedWelcomeHandle(ptr: stagedWelcomePtr)
    }
    
    /// Complete group join from staged welcome
    public static func completeGroupJoin(
        stagedWelcome: StagedWelcomeHandle,
        signer: SignerHandle? = nil
    ) throws -> GroupHandle {
        print("[OpenMLS] Completing group join")
        let groupPtr = UnsafeMutablePointer<GroupContext>.allocate(capacity: 1)
        
        let result = complete_group_join(stagedWelcome.ptr, groupPtr)
        
        if !result.success {
            groupPtr.deallocate()
            
            if let errorMessagePtr = result.error_message {
                let errorMessage = String(cString: errorMessagePtr)
                print("[OpenMLS] Error completing group join: \(errorMessage)")
                free_error_message(result)
                throw OpenMLSError.ffiError(errorMessage)
            } else {
                print("[OpenMLS] Unknown error completing group join")
                throw OpenMLSError.ffiError("Unknown FFI error")
            }
        }
        
        let groupHandle = GroupHandle(ptr: groupPtr)
        
        // Store the signer with the group if provided
        if let signer = signer {
            storeSignerForGroup(groupHandle, signer: signer)
            print("[OpenMLS] Group joined successfully and signer stored")
        } else {
            print("[OpenMLS] Group joined successfully, but no signer provided to store")
        }
        
        return groupHandle
    }
    
    // MARK: - New Encryption/Decryption Methods
    
    /// Encrypt a message
    public static func encryptMessage(group: GroupHandle,
                                 signer: SignerHandle,
                                 messageData: Data) throws -> Data {
        var dataPtr: UnsafeMutablePointer<UInt8>?
        var dataLen: Int = 0
        
        let result = messageData.withUnsafeBytes { bufferPtr in
            encrypt_message(
                group.ptr,
                signer.ptr,
                bufferPtr.baseAddress?.assumingMemoryBound(to: UInt8.self),
                messageData.count,
                &dataPtr,
                &dataLen
            )
        }
        
        if !result.success {
            if let errorMessagePtr = result.error_message {
                let errorMessage = String(cString: errorMessagePtr)
                free_error_message(result)
                throw OpenMLSError.ffiError(errorMessage)
            } else {
                throw OpenMLSError.ffiError("Unknown FFI error")
            }
        }
        
        guard let ptr = dataPtr else {
            throw OpenMLSError.nullPointer
        }
        
        let data = Data(bytes: ptr, count: dataLen)
        free_buffer(ptr, dataLen)
        
        return data
    }
    
    /// Decrypt a message
    public static func decryptMessage(group: GroupHandle,
                                 messageData: Data) throws -> Data {
        var dataPtr: UnsafeMutablePointer<UInt8>?
        var dataLen: Int = 0
        
        let result = messageData.withUnsafeBytes { bufferPtr in
            decrypt_message(
                group.ptr,
                bufferPtr.baseAddress?.assumingMemoryBound(to: UInt8.self),
                messageData.count,
                &dataPtr,
                &dataLen
            )
        }
        
        if !result.success {
            if let errorMessagePtr = result.error_message {
                let errorMessage = String(cString: errorMessagePtr)
                free_error_message(result)
                throw OpenMLSError.ffiError(errorMessage)
            } else {
                throw OpenMLSError.ffiError("Unknown FFI error")
            }
        }
        
        guard let ptr = dataPtr else {
            throw OpenMLSError.nullPointer
        }
        
        let data = Data(bytes: ptr, count: dataLen)
        free_buffer(ptr, dataLen)
        
        return data
    }
    
    /// Helper for sending text messages
    public static func sendMessage(
        group: GroupHandle,
        message: String,
        signer: SignerHandle? = nil
    ) throws -> Data {
        print("[OpenMLS] sendMessage called with message length: \(message.count)")
        
        // Check for a stored or provided signer
        let signerToUse = signer ?? getSignerForGroup(group)
        
        if let signerToUse = signerToUse {
            // Use the consistent signer if available
            print("[OpenMLS] Using consistent signer for message")
            guard let messageData = message.data(using: .utf8) else {
                throw OpenMLSError.ffiError("Failed to encode message as UTF-8")
            }
            
            var dataPtr: UnsafeMutablePointer<UInt8>?
            var dataLen: Int = 0
            
            let result = messageData.withUnsafeBytes { bufferPtr in
                encrypt_message_with_signer(
                    group.ptr,
                    signerToUse.ptr,
                    bufferPtr.baseAddress?.assumingMemoryBound(to: UInt8.self),
                    messageData.count,
                    &dataPtr,
                    &dataLen
                )
            }
            
            if !result.success {
                if let errorMessagePtr = result.error_message {
                    let errorMessage = String(cString: errorMessagePtr)
                    print("[OpenMLS] Error in encrypt_message_with_signer: \(errorMessage)")
                    free_error_message(result)
                    throw OpenMLSError.ffiError(errorMessage)
                } else {
                    print("[OpenMLS] Unknown error in encrypt_message_with_signer")
                    throw OpenMLSError.ffiError("Unknown FFI error")
                }
            }
            
            guard let ptr = dataPtr else {
                print("[OpenMLS] Null pointer returned from encrypt_message_with_signer")
                throw OpenMLSError.nullPointer
            }
            
            let data = Data(bytes: ptr, count: dataLen)
            print("[OpenMLS] Message encrypted successfully with consistent signer, length: \(data.count)")
            free_buffer(ptr, dataLen)
            
            return data
            
        } else {
            // Fall back to the original method with temporary signer if needed
            print("[OpenMLS] No consistent signer found, using temporary signer")
            
            var dataPtr: UnsafeMutablePointer<UInt8>?
            var dataLen: Int = 0
            
            let result = message.withCString { messagePtr in
                send_message(
                    group.ptr,
                    messagePtr,
                    &dataPtr,
                    &dataLen
                )
            }
            
            if !result.success {
                if let errorMessagePtr = result.error_message {
                    let errorMessage = String(cString: errorMessagePtr)
                    print("[OpenMLS] Error in send_message: \(errorMessage)")
                    free_error_message(result)
                    throw OpenMLSError.ffiError(errorMessage)
                } else {
                    print("[OpenMLS] Unknown error in send_message")
                    throw OpenMLSError.ffiError("Unknown FFI error")
                }
            }
            
            guard let ptr = dataPtr else {
                print("[OpenMLS] Null pointer returned from send_message")
                throw OpenMLSError.nullPointer
            }
            
            let data = Data(bytes: ptr, count: dataLen)
            print("[OpenMLS] Message encrypted successfully with temporary signer, length: \(data.count)")
            free_buffer(ptr, dataLen)
            
            return data
        }
    }
    
    /// Serialize a key package for storage
    public static func serializeKeyPackage(keyPackage: KeyPackageHandle) throws -> Data {
        var dataPtr: UnsafeMutablePointer<UInt8>?
        var dataLen: Int = 0
        
        let result = serialize_key_package(
            keyPackage.ptr,
            &dataPtr,
            &dataLen
        )
        
        if !result.success {
            if let errorMessagePtr = result.error_message {
                let errorMessage = String(cString: errorMessagePtr)
                free_error_message(result)
                throw OpenMLSError.ffiError(errorMessage)
            } else {
                throw OpenMLSError.ffiError("Unknown FFI error")
            }
        }
        
        guard let ptr = dataPtr else {
            throw OpenMLSError.nullPointer
        }
        
        let data = Data(bytes: ptr, count: dataLen)
        free_buffer(ptr, dataLen)
        
        return data
    }
    
    /// Deserialize a key package from storage
    public static func deserializeKeyPackage(data: Data) throws -> KeyPackageHandle {
        let keyPackagePtr = UnsafeMutablePointer<KeyPackageContext>.allocate(capacity: 1)
        
        let result = data.withUnsafeBytes { dataPtr in
            deserialize_key_package(
                dataPtr.baseAddress?.assumingMemoryBound(to: UInt8.self),
                data.count,
                keyPackagePtr
            )
        }
        
        if !result.success {
            keyPackagePtr.deallocate()
            
            if let errorMessagePtr = result.error_message {
                let errorMessage = String(cString: errorMessagePtr)
                free_error_message(result)
                throw OpenMLSError.ffiError(errorMessage)
            } else {
                throw OpenMLSError.ffiError("Unknown FFI error")
            }
        }
        
        return KeyPackageHandle(ptr: keyPackagePtr)
    }
    
    // MARK: - Resource cleanup
    
    /// Free credential resources
    public static func freeCredential(_ credential: CredentialHandle) {
        free_credential(credential.ptr.pointee)
        credential.ptr.deallocate()
    }
    
    /// Free signer resources
    public static func freeSigner(_ signer: SignerHandle) {
        free_signer(signer.ptr.pointee)
        signer.ptr.deallocate()
    }
    
    /// Free key package resources
    public static func freeKeyPackage(_ keyPackage: KeyPackageHandle) {
        free_key_package(keyPackage.ptr.pointee)
        keyPackage.ptr.deallocate()
    }
    
    /// Free group resources
    public static func freeGroup(_ group: GroupHandle) {
        free_group(group.ptr.pointee)
        group.ptr.deallocate()
    }
    
    /// Free welcome resources
    public static func freeWelcome(_ welcome: WelcomeHandle) {
        free_welcome(welcome.ptr.pointee)
        welcome.ptr.deallocate()
    }
    
    /// Free staged welcome resources
    public static func freeStagedWelcome(_ stagedWelcome: StagedWelcomeHandle) {
        free_staged_welcome(stagedWelcome.ptr.pointee)
        stagedWelcome.ptr.deallocate()
    }
    
    /// Free message out resources
    public static func freeMessageOut(_ messageOut: MlsMessageOutContext) {
        free_message_out(messageOut)
    }
}

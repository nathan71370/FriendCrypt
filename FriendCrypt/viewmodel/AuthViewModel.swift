//
//  AuthViewModel.swift
//  Friendly
//
//  Created by Nathan Mercier on 07/02/2025.
//  Adapted for custom OpenMLS bridge
//
//
import SwiftUI
import FirebaseFirestore
import FirebaseMessaging
import FirebaseAuth

class AuthViewModel: ObservableObject {
    static let shared = AuthViewModel()
    
    @Published var user: ChatUser?
    @Published var isLoggedIn = false
    @Published var signupError: String? = nil
    
    private var authStateListenerHandle: AuthStateDidChangeListenerHandle?
    private var userListener: ListenerRegistration?
    
    init() {
        try? Auth.auth().signOut()
        authStateListenerHandle = Auth.auth().addStateDidChangeListener { auth, fbUser in
            if let fbUser = fbUser {
                self.isLoggedIn = true
                let userRef = Firestore.firestore().collection("users").document(fbUser.uid)
                
                self.userListener?.remove()
                
                self.userListener = userRef.addSnapshotListener { snapshot, error in
                    if let error = error {
                        print("Error listening to user doc: \(error)")
                        return
                    }
                    
                    guard let snapshot = snapshot, snapshot.exists else {
                        print("User doc does not exist for uid: \(fbUser.uid)")
                        return
                    }
                    
                    do {
                        let chatUser = try snapshot.data(as: ChatUser.self)
                        DispatchQueue.main.async {
                            self.user = chatUser
                        }
                    } catch {
                        print("Error decoding user: \(error)")
                    }
                }
            } else {
                self.isLoggedIn = false
                self.user = nil
                self.userListener?.remove()
                self.userListener = nil
            }
        }
    }
    
    
    func signIn(email: String, password: String) {
        Auth.auth().signIn(withEmail: email, password: password) { result, error in
            
            //if let userId = result?.user.uid {
                    //self.setupMlsCredentials(for: userId)
              //      }
            
            if let error = error {
                print("Error signing in: \(error.localizedDescription)")
            }
        }
    }
    
    func signUp(email: String, password: String, username: String) {
        let db = Firestore.firestore()
        
        db.collection("users").whereField("username", isEqualTo: username).getDocuments { snapshot, error in
            if let error = error {
                DispatchQueue.main.async {
                    self.signupError = "Error checking username: \(error.localizedDescription)"
                }
                return
            }
            
            if let snapshot = snapshot, !snapshot.documents.isEmpty {
                DispatchQueue.main.async {
                    self.signupError = "Username already exists. Please choose another one."
                }
                return
            }
            
            Auth.auth().createUser(withEmail: email, password: password) { result, error in
                if let error = error {
                    DispatchQueue.main.async {
                        self.signupError = "Error signing up: \(error.localizedDescription)"
                    }
                    return
                }
                guard let result = result else { return }
                
                let newUser = ChatUser(email: email, username: username)
                do {
                    try db.collection("users")
                        .document(result.user.uid)
                        .setData(from: newUser) { err in
                            if let err = err {
                                DispatchQueue.main.async {
                                    self.signupError = "Error writing user data: \(err.localizedDescription)"
                                }
                            } else {
                                self.setupMlsCredentials(for: result.user.uid)
                                // Now that the user is created, fetch and update the FCM token:
                                Messaging.messaging().token { token, error in
                                    if let error = error {
                                        print("Error fetching FCM registration token: \(error)")
                                    } else if let token = token {
                                        db.collection("users")
                                            .document(result.user.uid)
                                            .updateData(["fcmToken": token]) { updateError in
                                                if let updateError = updateError {
                                                    print("Error updating FCM token: \(updateError)")
                                                } else {
                                                    print("FCM token updated successfully after sign up.")
                                                }
                                            }
                                    }
                                }
                            }
                        }
                } catch {
                    DispatchQueue.main.async {
                        self.signupError = "Error writing user data: \(error.localizedDescription)"
                    }
                }
            }
        }
    }

    func runFixedMlsDiagnosticTest() {
        print("\n===== STARTING IMPROVED MLS DIAGNOSTIC TEST =====\n")
        
        do {
            print("1. Creating Alice's credentials")
            let (aliceCredential, aliceSigner) = try OpenMLS.generateCredential(identity: "alice")
            
            print("2. Creating Alice's group")
            let aliceGroup = try OpenMLS.createGroup(signer: aliceSigner, credential: aliceCredential)
            
            print("3. Creating Bob's credentials")
            let (bobCredential, bobSigner) = try OpenMLS.generateCredential(identity: "bob")
            
            print("4. Creating Bob's key package")
            let bobKeyPackage = try OpenMLS.generateKeyPackage(
                signer: bobSigner,
                credential: bobCredential
            )
            
            print("5. Alice adding Bob to her group")
            let welcome = try OpenMLS.addMembers(
                group: aliceGroup,
                signer: aliceSigner,
                keyPackages: [bobKeyPackage]
            )
            
            print("6. Alice merging the commit")
            try OpenMLS.mergePendingCommit(group: aliceGroup)
            
            print("7. Alice exporting the ratchet tree")
            let ratchetTree = try OpenMLS.exportRatchetTree(group: aliceGroup)
            print("   Ratchet tree size: \(ratchetTree.count) bytes")
            
            print("8. Serializing the welcome message")
            let welcomeData = try OpenMLS.serializeWelcome(welcome: welcome)
            print("   Welcome message size: \(welcomeData.count) bytes")
            
            print("9. Bob deserializing the welcome")
            let bobWelcome = try OpenMLS.deserializeWelcome(data: welcomeData)
            
            print("10. Bob creating staged welcome")
            let stagedWelcome = try OpenMLS.createStagedWelcome(
                welcome: bobWelcome,
                ratchetTreeData: ratchetTree
            )
            
            print("11. Bob completing the group join")
            let bobGroup = try OpenMLS.completeGroupJoin(
                stagedWelcome: stagedWelcome,
                signer: bobSigner  // Pass Bob's signer to store with the group
            )
            
            // First message: Alice to Bob
            print("\n-- First message flow: Alice → Bob --\n")
            
            print("12. Alice encrypting a message using her consistent signer")
            let messageText = "Hello Bob, this is Alice!"
            let encryptedData = try OpenMLS.sendMessage(
                group: aliceGroup,
                message: messageText,
                signer: aliceSigner  // Use Alice's original signer
            )
            print("   Encrypted message size: \(encryptedData.count) bytes")
            
            print("13. Bob trying to decrypt Alice's message")
            do {
                let decryptedData = try OpenMLS.decryptMessage(
                    group: bobGroup,
                    messageData: encryptedData
                )
                
                if let decryptedString = String(data: decryptedData, encoding: .utf8) {
                    print("   ✅ DECRYPTION SUCCESS!")
                    print("   Original: \"\(messageText)\"")
                    print("   Decrypted: \"\(decryptedString)\"")
                } else {
                    print("   ❌ Decryption produced invalid UTF-8 data")
                }
            } catch {
                print("   ❌ DECRYPTION FAILED: \(error)")
            }
            
            // Second message: Bob to Alice
            print("\n-- Second message flow: Bob → Alice --\n")
            
            print("14. Bob encrypting a reply using his consistent signer")
            let replyText = "Hello Alice, this is Bob!"
            let encryptedReply = try OpenMLS.sendMessage(
                group: bobGroup,
                message: replyText,
                signer: bobSigner  // Use Bob's original signer
            )
            print("   Encrypted reply size: \(encryptedReply.count) bytes")
            
            print("15. Alice trying to decrypt Bob's message")
            do {
                let decryptedReply = try OpenMLS.decryptMessage(
                    group: aliceGroup,
                    messageData: encryptedReply
                )
                
                if let decryptedString = String(data: decryptedReply, encoding: .utf8) {
                    print("   ✅ DECRYPTION SUCCESS!")
                    print("   Original: \"\(replyText)\"")
                    print("   Decrypted: \"\(decryptedString)\"")
                } else {
                    print("   ❌ Decryption produced invalid UTF-8 data")
                }
            } catch {
                print("   ❌ DECRYPTION FAILED: \(error)")
            }
            
            print("\n===== TEST COMPLETED =====\n")
            
        } catch {
            print("❌ TEST FAILED: \(error)")
        }
    }
    
    func signOut() {
        do {
            try Auth.auth().signOut()
        } catch {
            print("Error signing out: \(error.localizedDescription)")
        }
    }
    
    func setupMlsCredentials(for userId: String) {
        do {
            // Generate credentials
            let (credential, signer) = try OpenMLS.generateCredential(identity: userId)
            
            // Generate a key package
            let keyPackage = try OpenMLS.generateKeyPackage(signer: signer, credential: credential)
            
            // Serialize the key package
            let serializedKeyPackage = try OpenMLS.serializeKeyPackage(keyPackage: keyPackage)
            let keyPackageBase64 = serializedKeyPackage.base64EncodedString()
            
            print("Key Package: \(keyPackageBase64)")
            
            // Update the user document
            Firestore.firestore().collection("users").document(userId)
                .updateData(["keyPackage": keyPackageBase64])
            
            // Clean up resources
            //OpenMLS.freeCredential(credential)
            //OpenMLS.freeSigner(signer)
            //OpenMLS.freeKeyPackage(keyPackage)
            
        } catch {
            print("Error setting up MLS credentials: \(error)")
        }
    }
}

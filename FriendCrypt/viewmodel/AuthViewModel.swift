//
//  AuthViewModel.swift
//  Friendly
//
//  Created by Nathan Mercier on 07/02/2025.
//
import SwiftUI
import FirebaseFirestore
import FirebaseAuth

class AuthViewModel: ObservableObject {
    static let shared = AuthViewModel()  // Singleton for convenience
    
    @Published var user: ChatUser?
    @Published var isLoggedIn = false
    @Published var signupError: String? = nil  // To hold signup error messages
    
    init() {
        // Listen for changes to the auth state.
        Auth.auth().addStateDidChangeListener { auth, fbUser in
            if let fbUser = fbUser {
                self.isLoggedIn = true
                // Fetch the user's document from Firestore.
                Firestore.firestore().collection("users").document(fbUser.uid).getDocument { snapshot, error in
                    if let error = error {
                        print("Error fetching user document: \(error.localizedDescription)")
                        return
                    }
                    
                    guard let snapshot = snapshot, snapshot.exists else {
                        print("User document does not exist for uid \(fbUser.uid)")
                        return
                    }
                    
                    do {
                        // Use the snapshot.data(as:) method to automatically decode and inject the document ID.
                        let chatUser = try snapshot.data(as: ChatUser.self)
                        DispatchQueue.main.async {
                            self.user = chatUser
                        }
                    } catch {
                        print("Error decoding user: \(error.localizedDescription)")
                    }
                }
            } else {
                self.isLoggedIn = false
                self.user = nil
            }
        }
    }
    
    func signIn(email: String, password: String) {
        Auth.auth().signIn(withEmail: email, password: password) { result, error in
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
                        .setData(from: newUser)
                } catch {
                    DispatchQueue.main.async {
                        self.signupError = "Error writing user data: \(error.localizedDescription)"
                    }
                }
            }
        }
    }
    
    func signOut() {
        do {
            try Auth.auth().signOut()
        } catch {
            print("Error signing out: \(error.localizedDescription)")
        }
    }
}

//
//  AddFriendView.swift
//  Friendly
//
//  Created by Nathan Mercier on 07/02/2025.
//
import SwiftUI
import FirebaseAuth
import FirebaseFirestore

struct AlertData: Identifiable {
    var id = UUID()
    let title: String
    let message: String
    let isError: Bool
}

struct AddFriendView: View {
    @Environment(\.presentationMode) var presentationMode
    @State private var friendUsername = ""
    @State private var alertData: AlertData? = nil
    
    var body: some View {
        NavigationView {
            VStack {
                TextField("Friend's Username", text: $friendUsername)
                    .keyboardType(.default)
                    .autocapitalization(.none)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding()
                
                Button(action: {
                    sendFriendRequest()
                }) {
                    Text("Add Friend")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
                .padding()
                Spacer()
            }
            .navigationTitle("Add Friend")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
            .alert(item: $alertData) { data in
                Alert(
                    title: Text(data.title),
                    message: Text(data.message),
                    dismissButton: .default(Text("OK"), action: {
                        if !data.isError {
                            presentationMode.wrappedValue.dismiss()
                        }
                    })
                )
            }
        }
    }
    
    func sendFriendRequest() {
        guard let currentUser = Auth.auth().currentUser else { return }
        let db = Firestore.firestore()
        
        db.collection("users")
            .whereField("username", isEqualTo: friendUsername)
            .getDocuments { snapshot, error in
                if let error = error {
                    alertData = AlertData(
                        title: "Error Sending Friend Request",
                        message: error.localizedDescription,
                        isError: true
                    )
                    print("Error finding friend: \(error.localizedDescription)")
                    return
                }
                guard let documents = snapshot?.documents,
                      let friendDoc = documents.first else {
                    alertData = AlertData(
                        title: "Error Sending Friend Request",
                        message: "Friend not found",
                        isError: true
                    )
                    print("Friend not found")
                    return
                }
                
                if friendDoc.documentID == currentUser.uid {
                    alertData = AlertData(
                        title: "Error Sending Friend Request",
                        message: "Cannot send a friend request to yourself",
                        isError: true
                    )
                    print("Cannot send a friend request to yourself")
                    return
                }
                
                if (friendDoc["friend_requests"] as? [String] ?? []).contains(currentUser.uid) {
                    alertData = AlertData(
                        title: "Error Sending Friend Request",
                        message: "You have already sent a friend request to this user",
                        isError: true
                    )
                    print("You have already sent a friend request to this user")
                    return
                }
                
                if (friendDoc["friends"] as? [String] ?? []).contains(currentUser.uid) {
                    alertData = AlertData(
                        title: "Error Sending Friend Request",
                        message: "You are already friends with this user",
                        isError: true
                    )
                    print("You are already friends with this user")
                    return
                }
                
                if (friendDoc["friend_requests"] as? [String] ?? []).contains(currentUser.uid) {
                    // The target user has already sent you a friend request, so auto-accept for both sides.
                    autoAcceptMutualRequest(currentUserId: currentUser.uid, friendId: friendDoc.documentID)
                    alertData = AlertData(
                        title: "You Are Now Friends!",
                        message: "The user had already sent you a request, so we accepted automatically.",
                        isError: false
                    )
                    return
                }
                
                db.collection("users").document(friendDoc.documentID).updateData([
                    "friend_requests": FieldValue.arrayUnion([currentUser.uid])
                ]) { error in
                    if let error = error {
                        alertData = AlertData(
                            title: "Error Sending Friend Request",
                            message: error.localizedDescription,
                            isError: true
                        )
                        print("Error sending friend request: \(error.localizedDescription)")
                    } else {
                        alertData = AlertData(
                            title: "Friend Request Sent",
                            message: "Your friend request has been sent successfully to \(friendUsername).",
                            isError: false
                        )
                        print("Friend request sent!")
                    }
                }
            }
    }
    
    func autoAcceptMutualRequest(currentUserId: String, friendId: String) {
        let db = Firestore.firestore()
        
        let currentUserRef = db.collection("users").document(currentUserId)
        let friendUserRef = db.collection("users").document(friendId)
        
        // Transaction to update your own user: remove friendId from friend_requests and add to friends.
        db.runTransaction({ transaction, errorPointer in
            let currentUserDoc: DocumentSnapshot
            do {
                currentUserDoc = try transaction.getDocument(currentUserRef)
            } catch let error as NSError {
                errorPointer?.pointee = error
                return nil
            }
            
            let currentData = currentUserDoc.data() ?? [:]
            var friendRequests = currentData["friend_requests"] as? [String] ?? []
            var friends = currentData["friends"] as? [String] ?? []
            
            friendRequests.removeAll(where: { $0 == friendId })
            if !friends.contains(friendId) {
                friends.append(friendId)
            }
            
            transaction.updateData([
                "friend_requests": friendRequests,
                "friends": friends
            ], forDocument: currentUserRef)
            
            return nil
        }, completion: { error, _ in
            if let error = error {
                print("Auto-accept transaction failed: \(error)")
            }
        })
        
        // Also add your id to the friend's "friends" array.
        friendUserRef.updateData([
            "friends": FieldValue.arrayUnion([currentUserId])
        ]) { error in
            if let error = error {
                print("Error auto-updating the friend's document: \(error.localizedDescription)")
            }
        }
    }
}

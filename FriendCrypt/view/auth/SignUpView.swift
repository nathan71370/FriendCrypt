//
//  SignUpView.swift
//  Friendly
//
//  Created by Nathan Mercier on 07/02/2025.
//

import SwiftUI
import FirebaseAuth

// Extend String to conform to Identifiable
extension String: Identifiable {
    public var id: String { self }
}

struct SignUpView: View {
    @State private var email = ""
    @State private var password = ""
    @State private var username = ""
    @ObservedObject var authVM = AuthViewModel.shared
    
    var body: some View {
        VStack(spacing: 20) {
            TextField("Display Name", text: $username)
                .autocapitalization(.none)
                .textFieldStyle(RoundedBorderTextFieldStyle())
            TextField("Email", text: $email)
                .keyboardType(.emailAddress)
                .autocapitalization(.none)
                .textFieldStyle(RoundedBorderTextFieldStyle())
            SecureField("Password", text: $password)
                .textFieldStyle(RoundedBorderTextFieldStyle())
            Button(action: {
                authVM.signUp(email: email, password: password, username: username)
            }) {
                Text("Sign Up")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.green)
                    .foregroundColor(.white)
                    .cornerRadius(8)
            }
        }
        .padding()
        .navigationTitle("Sign Up")
        // Add an alert that is presented when signupError is non-nil.
        .alert(item: $authVM.signupError) { error in
            Alert(
                title: Text("Signup Error"),
                message: Text(error),
                dismissButton: .default(Text("OK"), action: {
                    authVM.signupError = nil
                })
            )
        }
    }
}

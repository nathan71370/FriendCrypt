//
//  ConversationInfoView.swift
//  Friendly
//
//  Created by Nathan Mercier on 08/02/2025.
//

import SwiftUI

struct ConversationInfoView: View {
    let conversationId: String
    @EnvironmentObject var authVM: AuthViewModel
    @EnvironmentObject var conversationVM: ConversationsViewModel
    @StateObject private var friendVM = FriendViewModel()
    @StateObject private var userLookupVM = UserLookupViewModel()
    @State private var showAddFriendSheet = false
    @Environment(\.dismiss) var dismiss
    
    
    
    init(conversationId: String) {
        self.conversationId = conversationId
    }
    
    var body: some View {
        NavigationView {
            List {
                Section(header: Text("Participants")) {
                    if let conversation = conversationVM.conversation(for: conversationId) {
                        ForEach(conversation.participants, id: \.self) { participantId in
                            if participantId == authVM.user?.id {
                                Text(authVM.user?.username ?? participantId)
                            } else {
                                Text(userLookupVM.username(for: participantId))
                            }
                        }
                    } else {
                        Text("Loading...")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("Conversation Info")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        showAddFriendSheet = true
                    }) {
                        Image(systemName: "plus")
                    }
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(isPresented: $showAddFriendSheet) {
                AddFriendToConversationView(conversationId: conversationId)
                    .environmentObject(authVM)
            }
        }
        .onAppear {
            if let currentUser = authVM.user {
                friendVM.fetchFriends(for: currentUser)
            }
        }
    }
}

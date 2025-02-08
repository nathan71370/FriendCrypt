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
    @StateObject private var convDetailVM = ConversationDetailViewModel(conversationId: "")
    @StateObject private var friendVM = FriendViewModel()  // For looking up participant names
    @State private var showAddFriendSheet = false
    @Environment(\.dismiss) var dismiss
    
    init(conversationId: String) {
        self.conversationId = conversationId
        _convDetailVM = StateObject(wrappedValue: ConversationDetailViewModel(conversationId: conversationId))
    }
    
    var body: some View {
        NavigationView {
            List {
                Section(header: Text("Participants")) {
                    if let conversation = convDetailVM.conversation {
                        ForEach(conversation.participants, id: \.self) { participantId in
                            // If this participant is the current user, show their username directly.
                            if participantId == authVM.user?.id {
                                Text(authVM.user?.username ?? participantId)
                            } else {
                                // Otherwise, look it up in friendVM.friends.
                                Text(friendVM.friends.first(where: { $0.id == participantId })?.username ?? participantId)
                            }
                        }
                    } else {
                        Text("Loading participants...")
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

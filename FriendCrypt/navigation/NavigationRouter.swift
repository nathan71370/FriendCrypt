//
//  NavigationRouter.swift
//  FriendCrypt
//
//  Created by Nathan Mercier on 13/02/2025.
//


import SwiftUI

final class NavigationRouter: ObservableObject {
    static let shared = NavigationRouter()
    @Published var path = NavigationPath()
    
    // Track the currently visible conversation (if any)
    private var currentConversationID: String?
    
    // A pending deep link that gets processed on launch.
    var pendingDeepLink: DeepLink? {
        didSet {
            if let link = pendingDeepLink {
                navigate(to: link)
                pendingDeepLink = nil
            }
        }
    }
    
    func navigate(to link: DeepLink) {
        // If the deep link is for a conversation, check if it's already visible.
        if case let .conversation(id) = link {
            if currentConversationID == id {
                // The conversation is already showing, so do nothing.
                print("Conversation \(id) already visible, not pushing again.")
                return
            } else {
                // Update the currently visible conversation.
                currentConversationID = id
            }
        }
        path.append(link)
    }
    
    /// Call this when the conversation view is dismissed.
    func clearCurrentConversation() {
        currentConversationID = nil
    }
}

//
//  ConversationRowView.swift
//  FriendCrypt
//
//  Created by Nathan Mercier on 15/02/2025.
//

import SwiftUI

extension String {
    /// Returns a truncated version of the string if it exceeds the specified length.
    /// - Parameters:
    ///   - length: The maximum number of characters to include before truncating.
    ///   - trailing: The string to append after truncation (default is "...")
    /// - Returns: The truncated string with trailing characters if needed.
    func truncated(to length: Int, trailing: String = "...") -> String {
        if self.count > length {
            return String(self.prefix(length)) + trailing
        } else {
            return self
        }
    }
}

extension Date {
    /// Returns a formatted string for the timestamp.
    /// If the date is today, returns "HH:mm", otherwise "dd/MM".
    func formattedTimestamp() -> String {
        let formatter = DateFormatter()
        let calendar = Calendar.current
        if calendar.isDateInToday(self) {
            formatter.dateFormat = "HH:mm"
        } else {
            formatter.dateFormat = "dd/MM"
        }
        return formatter.string(from: self)
    }
}

struct ConversationRowView: View {
    let conversation: Conversation
    
    @EnvironmentObject var conversationsVM: ConversationsViewModel
    @EnvironmentObject var friendVM: FriendViewModel
    @EnvironmentObject var authVM: AuthViewModel
    @State private var lastMessage: Message?
    
    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                if conversation.participants.count == 2 {
                    Text(friendVM.friendName(for: conversation))
                        .font(.headline)
                } else if conversation.participants.count == 1 {
                    Text(authVM.user?.username ?? "Chat")
                        .font(.headline)
                } else {
                    Text("\(conversation.participants.count) people")
                        .font(.headline)
                }
                Text(lastMessage?.text.truncated(to: 20) ?? "Loading…")
                    .font(.subheadline)
            }
            Spacer()
            // Display the timestamp if available
            if let timestamp = lastMessage?.timestamp.dateValue() {
                Text(timestamp.formattedTimestamp())
                    .font(.caption)
                    .foregroundColor(.gray)
            }
        }
        .padding(.vertical, 8)
        .task {
            do {
                lastMessage = try await conversationsVM.lastMessage(conversation: conversation)
            } catch {
                print("Error fetching last message: \(error)")
            }
        }
    }
}

//
//  MessageBubbleView.swift
//  FriendCrypt
//
//  Created by Nathan Mercier on 15/02/2025.
//


import SwiftUI
import FirebaseFirestore

struct MessageBubbleView: View {
    let message: Message
    let isCurrentUser: Bool
    let senderName: String
    /// Pass the conversation’s participant count so we know whether to show the sender name.
    let conversationParticipantsCount: Int

    @State private var showTimestamp = false

    var body: some View {
        VStack(alignment: isCurrentUser ? .trailing : .leading, spacing: 4) {
            // Only show sender name if conversation has more than one participant and the message is not from the current user.
            if !isCurrentUser && conversationParticipantsCount > 2 {
                Text(senderName)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Text(message.text)
                .padding()
                .background(isCurrentUser ? Color.blue : Color.gray.opacity(0.2))
                .foregroundColor(isCurrentUser ? .white : .primary)
                .cornerRadius(12)
            if showTimestamp {
                Text(formattedTimestamp(message.timestamp))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: isCurrentUser ? .trailing : .leading)
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 20)
                .onChanged { value in
                    // If swiping left, reveal the timestamp
                    if value.translation.width < 0 {
                        withAnimation { showTimestamp = true }
                    }
                }
                .onEnded { _ in
                    // Optionally hide after a short delay or immediately
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                        withAnimation { showTimestamp = false }
                    }
                }
        )
    }

    private func formattedTimestamp(_ timestamp: Timestamp) -> String {
        let date = timestamp.dateValue()
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

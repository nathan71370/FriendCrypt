import SwiftUI
import FirebaseFirestore

struct MessageBubbleView: View {
    let message: Message
    let isCurrentUser: Bool
    let senderName: String
    let conversationParticipantsCount: Int
    
    // Add this property to accept the display text from ChatView
    let displayText: String
    
    @State private var showTimestamp = false

    var body: some View {
        VStack(alignment: isCurrentUser ? .trailing : .leading, spacing: 4) {
            if !isCurrentUser && conversationParticipantsCount > 2 {
                Text(senderName)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            // Use the displayText parameter instead of message.text
            Text(displayText)
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
                    if value.translation.width < 0 {
                        withAnimation { showTimestamp = true }
                    }
                }
                .onEnded { _ in
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

// An initializer extension to make the transition easier and provide backward compatibility
extension MessageBubbleView {
    init(message: Message, isCurrentUser: Bool, senderName: String, conversationParticipantsCount: Int) {
        self.message = message
        self.isCurrentUser = isCurrentUser
        self.senderName = senderName
        self.conversationParticipantsCount = conversationParticipantsCount
        self.displayText = message.text
    }
}

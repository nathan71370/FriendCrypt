//
//  GrowingTextView.swift
//  FriendCrypt
//
//  Created by Nathan Mercier on 16/02/2025.
//


import SwiftUI

/// A SwiftUI view that provides a TextEditor which grows with its content,
/// showing a placeholder when empty. It auto-wraps text and expands from a minimum
/// height (e.g. 2 lines) up to a maximum (e.g. 4 lines) before scrolling.
struct GrowingTextEditor: View {
    @Binding var text: String
    let placeholder: String
    let minHeight: CGFloat
    let maxHeight: CGFloat

    // This state holds the calculated height of the text content.
    @State private var dynamicHeight: CGFloat = 0

    var body: some View {
        ZStack(alignment: .topLeading) {
            // Placeholder text
            if text.isEmpty {
                Text(placeholder)
                    .foregroundColor(Color(UIColor.placeholderText))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 12)
            }
            // The editable text area
            TextEditor(text: $text)
                .padding(4)
                .background(Color.clear)
                // When the view appears or text changes, recalc the height.
                .background(
                    TextHeightReader(text: text, minWidth: UIScreen.main.bounds.width - 32) { calculatedHeight in
                        // Add extra padding if needed (here 20 is an approximate adjustment).
                        self.dynamicHeight = calculatedHeight + 20
                    }
                )
                // Set the height to be at least minHeight, up to maxHeight.
                .frame(height: min(max(dynamicHeight, minHeight), maxHeight))
                .cornerRadius(8)
        }
    }
}

/// A helper view that uses an invisible Text view to measure height.
struct TextHeightReader: View {
    let text: String
    let minWidth: CGFloat
    let callback: (CGFloat) -> Void

    var body: some View {
        // Use a Text view with the same styling as your TextEditor.
        Text(text)
            .font(.body)
            .lineSpacing(4)
            .padding(4)
            .frame(width: minWidth, alignment: .leading)
            .background(
                GeometryReader { geo in
                    Color.clear
                        .onAppear {
                            callback(geo.size.height)
                        }
                        .onChange (of: geo.size) {
                            callback(geo.size.height)
                        }
                }
            )
            .hidden() // Keep it out of sight.
    }
}

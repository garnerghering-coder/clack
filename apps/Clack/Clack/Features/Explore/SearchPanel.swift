//
//  SearchPanel.swift
//  Clack
//

import ClackDesign
import SwiftUI

/// The glass card under Explore's search field (the results, or your stations before anything is typed). It hugs its
/// content up to `maxHeight` and the room above the keyboard, then scrolls inside that height: nothing lies outside
/// what's drawn, so nothing is cropped and no hidden row takes taps.
struct SearchPanel<Content: View>: View {
    var maxHeight: CGFloat
    @ViewBuilder var content: Content
    @State private var contentHeight: CGFloat = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ScrollView {
                rows.onGeometryChange(for: CGFloat.self) { $0.size.height } action: { contentHeight = $0 }
            }
            .scrollBounceBehavior(.basedOnSize)
            .scrollDismissesKeyboard(.interactively)
            // As tall as the rows, at most `maxHeight`, and at most the room the stack leaves (keyboard included).
            .frame(maxWidth: 460, maxHeight: min(contentHeight, maxHeight))
            .background(Ink.glass).background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
            .hairlineBorder(radius: Radius.card)
            .clackShadow()
            Spacer(minLength: 0)
        }
        // Below the field (12 + 48 + 4), and above the keyboard and the map's attribution line.
        .padding(.horizontal, 12).padding(.top, 64).padding(.bottom, 32)
    }

    private var rows: some View {
        content
            .padding(.horizontal, 16).padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

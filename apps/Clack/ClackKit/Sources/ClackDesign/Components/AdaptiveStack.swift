//
//  AdaptiveStack.swift
//  ClackDesign
//

import SwiftUI

/// A row that stacks its parts vertically at the accessibility text sizes, so long station names and times never
/// squeeze or truncate (polish pass 1, DECISIONS C6).
public struct AdaptiveStack<Content: View>: View {
    var horizontalAlignment: HorizontalAlignment
    var verticalAlignment: VerticalAlignment
    var spacing: CGFloat
    @ViewBuilder var content: Content
    @Environment(\.dynamicTypeSize) private var typeSize

    public init(
        horizontalAlignment: HorizontalAlignment = .leading, verticalAlignment: VerticalAlignment = .center,
        spacing: CGFloat = Space.s, @ViewBuilder content: () -> Content
    ) {
        self.horizontalAlignment = horizontalAlignment
        self.verticalAlignment = verticalAlignment
        self.spacing = spacing
        self.content = content()
    }

    public var body: some View {
        let layout = typeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: horizontalAlignment, spacing: spacing))
            : AnyLayout(HStackLayout(alignment: verticalAlignment, spacing: spacing))
        layout { content }
    }
}

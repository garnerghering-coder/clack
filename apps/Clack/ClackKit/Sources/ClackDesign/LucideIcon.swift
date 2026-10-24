//
//  LucideIcon.swift
//  ClackDesign
//

import SwiftUI

/// A Lucide icon from ClackDesign's asset catalog, drawn as a template in the current foreground colour.
public struct LucideIcon: View {
    public let name: String
    public var size: CGFloat = 18
    /// The tab bar's icons are drawn at stroke 1.75; everything else at Lucide's default 2.
    public var thin = false

    public var body: some View {
        Image("lucide-\(name)\(thin ? "-thin" : "")", bundle: .module)
            .renderingMode(.template)
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
            .accessibilityHidden(true)
    }

    public init(name: String, size: CGFloat = 18, thin: Bool = false) {
        self.name = name
        self.size = size
        self.thin = thin
    }
}

/// The bundle holding the colour and icon asset catalog, for code that draws icons itself (a Canvas).
public enum ClackDesignBundle {
    public static var bundle: Bundle { .module }
}

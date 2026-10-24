//
//  LucideIcon.swift
//  ClackDesign
//

import SwiftUI

/// A Lucide icon from ClackDesign's asset catalog, drawn as a template in the current foreground colour. Decorative
/// (hidden from VoiceOver) unless it has a `label`: an icon that is the only sign of something (a platform change)
/// says it.
public struct LucideIcon: View {
    public let name: String
    public var size: CGFloat = 18
    /// The tab bar's icons are drawn at stroke 1.75; everything else at Lucide's default 2.
    public var thin = false
    /// The filled version (the favourite star when it is on).
    public var filled = false
    public var label: String?

    public var body: some View {
        let image = Image("lucide-\(name)\(thin ? "-thin" : "")\(filled ? "-filled" : "")", bundle: .module)
            .renderingMode(.template)
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
        if let label {
            image.accessibilityLabel(label)
        } else {
            image.accessibilityHidden(true)
        }
    }

    public init(name: String, size: CGFloat = 18, thin: Bool = false, filled: Bool = false, label: String? = nil) {
        self.name = name
        self.size = size
        self.thin = thin
        self.filled = filled
        self.label = label
    }
}

/// The bundle holding the colour and icon asset catalog, for code that draws icons itself (a Canvas).
public enum ClackDesignBundle {
    public static var bundle: Bundle { .module }
}

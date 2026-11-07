//
//  InfoNote.swift
//  ClackDesign
//

import ClackCore
import SwiftUI

/// A quiet short note (caption, text-2). When there is more to say, an (i) at its end opens the longer text under
/// it, and closes it again: a footnote never takes more than two lines until it is asked for.
public struct InfoNote: View {
    @Environment(L10n.self) private var l10n
    public let text: String
    public var more: String?
    @State private var open = false

    public init(_ text: String, more: String? = nil) {
        self.text = text
        self.more = more
    }

    public var body: some View {
        if let more, !more.isEmpty {
            VStack(alignment: .leading, spacing: 4) {
                Button {
                    open.toggle()
                } label: {
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        // Two lines closed (user test 2026-11-07: at large text sizes one line cut every footnote mid-word).
                        Text(text).lineLimit(open ? nil : 2).multilineTextAlignment(.leading)
                        LucideIcon(name: "info", size: 14).foregroundStyle(open ? Ink.accentInk : Ink.text3)
                            .alignmentGuide(.firstTextBaseline) { $0[VerticalAlignment.center] + 4 }
                        Spacer(minLength: 0)
                    }
                    .frame(minHeight: 44, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(text)
                .accessibilityHint(l10n.t(open ? "common.less" : "common.more"))
                .accessibilityAddTraits(open ? .isSelected : [])
                if open {
                    Text(more).fixedSize(horizontal: false, vertical: true)
                }
            }
            .clack(.caption)
            .foregroundStyle(Ink.text2)
        } else {
            Text(text).clack(.caption).foregroundStyle(Ink.text2).fixedSize(horizontal: false, vertical: true)
        }
    }
}

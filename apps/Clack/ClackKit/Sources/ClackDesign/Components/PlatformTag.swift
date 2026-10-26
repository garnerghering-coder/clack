//
//  PlatformTag.swift
//  ClackDesign
//

import ClackCore
import SwiftUI

/// `.platform-chip`: a platform number in a small tag (radius 6). Changed, it is written in the late ink on a faint late
/// tint, with the old number struck through before it.
public struct PlatformTag: View {
    @Environment(L10n.self) private var l10n
    public let platform: String
    public var changedFrom: String?

    public init(platform: String, changedFrom: String? = nil) {
        self.platform = platform
        self.changedFrom = changedFrom
    }

    public var body: some View {
        let changed = changedFrom != nil
        HStack(spacing: 4) {
            if let changedFrom, !changedFrom.isEmpty {
                Text(changedFrom).strikethrough().foregroundStyle(Ink.text3).fontWeight(.medium)
            }
            Text(platform)
        }
        .clack(.chip)
        .fontWeight(.bold)
        .monospacedDigit()
        .foregroundStyle(changed ? Ink.lateInk : Ink.text)
        .padding(.vertical, 2)
        .padding(.horizontal, 8)
        .frame(minWidth: 32)
        .background(changed ? Ink.late.opacity(0.18) : Ink.surfaceRaised, in: RoundedRectangle(cornerRadius: Radius.tag, style: .continuous))
        .fixedSize()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Format.join([
            l10n.t("trips.platform", ["platform": platform]),
            changedFrom.map { $0.isEmpty ? l10n.t("board.changed") : l10n.t("detail.platformChangedFrom", ["from": $0]) },
        ], separator: ", "))
    }
}

/// The platform column when no platform is known: the same tag with a dash, so rows line up (owner, 2026-10-25).
/// `onSet` makes it a button that asks for one (on your own trips, where nothing else knows it).
public struct UnknownPlatformTag: View {
    @Environment(L10n.self) private var l10n
    public var onSet: (() -> Void)?

    public init(onSet: (() -> Void)? = nil) { self.onSet = onSet }

    public var body: some View {
        let tag = Text(verbatim: "—")
            .clack(.chip)
            .fontWeight(.bold)
            .foregroundStyle(onSet == nil ? Ink.text3 : Ink.text2)
            .padding(.vertical, 2)
            .padding(.horizontal, 8)
            .frame(minWidth: 32)
            .background(Ink.surfaceRaised, in: RoundedRectangle(cornerRadius: Radius.tag, style: .continuous))
            .fixedSize()
        if let onSet {
            Button(action: onSet) { tag.frame(minWidth: 44, minHeight: 44, alignment: .trailing).contentShape(Rectangle()) }
                .buttonStyle(.plain)
                .accessibilityLabel(l10n.t("platform.add"))
        } else {
            tag.accessibilityLabel(l10n.t("platform.unknown"))
        }
    }
}

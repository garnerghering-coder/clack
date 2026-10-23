//
//  Shell.swift
//  Clack
//

import SwiftUI

/// The bottom tab bar (AppShell.tsx, styles.css `.tabbar`): Trips, Explore, Passport. A glass-strong bar with a
/// hairline on top; the active tab's label is `text`, its icon `accent-ink`; the others are `text-3`.
struct TabBar: View {
    @Environment(L10n.self) private var l10n
    @Binding var selection: PrimaryTab

    private static let items: [(tab: PrimaryTab, icon: String)] = [
        (.trips, "train-front"), (.explore, "compass"), (.passport, "stamp"),
    ]

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Self.items, id: \.tab) { item in
                let active = item.tab == selection
                Button {
                    selection = item.tab
                } label: {
                    VStack(spacing: 3) {
                        LucideIcon(name: item.icon, size: 22, thin: true)
                            .foregroundStyle(active ? Ink.accentInk : Ink.text3)
                        Text(l10n.t("nav.\(item.tab.rawValue)"))
                            .clack(.tab)
                            .foregroundStyle(active ? Ink.text : Ink.text3)
                    }
                    .textSelection(.disabled)
                    .frame(maxWidth: .infinity, minHeight: 64)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(active ? .isSelected : [])
            }
        }
        .background {
            ZStack {
                Rectangle().fill(.ultraThinMaterial)
                Ink.glassStrong
            }
            .ignoresSafeArea(edges: .bottom)
        }
        .overlay(alignment: .top) {
            Rectangle().fill(Ink.hairline).frame(height: 1)
        }
    }
}

/// `.page-header`: the large title with the actions on the right.
struct PageHeader<Trailing: View>: View {
    let title: String
    @ViewBuilder var trailing: Trailing

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Text(title)
                .clack(.pageTitle)
                .foregroundStyle(Ink.text)
                .lineLimit(2)
                .minimumScaleFactor(0.7)
                .accessibilityAddTraits(.isHeader)
            Spacer(minLength: 0)
            trailing
        }
        .padding(.top, 12)
    }
}

extension PageHeader where Trailing == EmptyView {
    init(title: String) {
        self.init(title: title) { EmptyView() }
    }
}

/// `.back-link`: accent-ink text with a chevron, at the top of a pushed screen.
struct BackLink: View {
    @Environment(L10n.self) private var l10n
    @Environment(\.dismiss) private var dismiss
    /// What it says; "Back" when not given.
    var label: String?

    var body: some View {
        Button {
            dismiss()
        } label: {
            HStack(spacing: 6) {
                LucideIcon(name: "arrow-left", size: 18)
                Text(label ?? l10n.t("common.back"))
            }
        }
        .buttonStyle(LinkButtonStyle())
    }
}

/// The page body: a scrolling column with 16 pt gutters and 16 pt between blocks (`.page`).
struct Page<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        ScrollView {
            // Lazy, with pinned section headers: the month headers stick to the top as they do on the web.
            LazyVStack(alignment: .leading, spacing: 16, pinnedViews: [.sectionHeaders]) {
                content
            }
            .frame(maxWidth: 720, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 24)
            .frame(maxWidth: .infinity)
        }
        .scrollBounceBehavior(.basedOnSize)
        .background(Ink.bg)
    }
}

/// The offline strip at the top of every screen while the server can't be reached (`.offline-banner`).
struct OfflineBanner: View {
    @Environment(L10n.self) private var l10n

    var body: some View {
        HStack(spacing: 6) {
            LucideIcon(name: "wifi-off", size: 14)
            Text(l10n.t("offline.banner")).lineLimit(1)
        }
        .clack(.init(size: 12, lineHeight: 16, weight: .semibold, style: .caption))
        .foregroundStyle(Ink.text2)
        .padding(.vertical, 4)
        .padding(.horizontal, 12)
        .background(Ink.surfaceRaised, in: RoundedRectangle(cornerRadius: Radius.controlSm, style: .continuous))
        .hairlineBorder(radius: Radius.controlSm)
        .shadow(color: .black.opacity(0.25), radius: 7, y: 4)
        .padding(.top, 6)
        .accessibilityElement(children: .combine)
    }
}

/// A modal sheet's frame (`.sheet`): a 28 pt title with a close button, then a scrolling body on the surface colour.
struct SheetFrame<Content: View>: View {
    @Environment(L10n.self) private var l10n
    let title: String
    var onClose: () -> Void
    @ViewBuilder var content: Content

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top, spacing: 12) {
                Text(title).clack(.sheetTitle).foregroundStyle(Ink.text).accessibilityAddTraits(.isHeader)
                Spacer(minLength: 0)
                IconButton(icon: "x", label: l10n.t("common.close"), action: onClose)
            }
            .padding(.top, 20)
            .padding(.horizontal, 16)
            .padding(.bottom, 8)
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    content
                }
                .padding(.top, 8)
                .padding(.horizontal, 16)
                .padding(.bottom, 32)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .background(Ink.surface)
        .presentationCornerRadius(Radius.sheet)
        .presentationBackground(Ink.surface)
    }
}

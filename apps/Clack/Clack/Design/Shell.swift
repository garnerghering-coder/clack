//
//  Shell.swift
//  Clack
//

import ClackCore
import ClackDesign
import SwiftUI

/// A Lucide icon as a toolbar button's image (the system draws the glass button around it).
func toolbarIcon(_ name: String) -> Image {
    Image("lucide-\(name)", bundle: ClackDesignBundle.bundle).renderingMode(.template)
}

extension View {
    /// Apple's screen title (owner, 2026-10-25): large at the top, shrinking into the bar as the page scrolls.
    func screenTitle(_ title: String) -> some View {
        navigationTitle(title).navigationBarTitleDisplayMode(.large)
    }

    /// A pushed screen with no title of its own: the system bar with its back button only.
    func plainBar() -> some View {
        navigationTitle("").navigationBarTitleDisplayMode(.inline)
    }
}

/// `.page-header`: the large title with the actions on the right (screens that draw their own, under a hidden bar).
struct PageHeader<Trailing: View>: View {
    let title: String
    @ViewBuilder var trailing: Trailing

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Text(title)
                .font(.largeTitle.bold())
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
        .scrollBounceBehavior(.always)
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
    /// The step's main button, pinned under the list (`.sheetAction`).
    @State private var action = SheetAction()

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
                VStack(alignment: .leading, spacing: 12) {
                    content
                }
                .padding(.top, 8)
                .padding(.horizontal, 16)
                .padding(.bottom, 32)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            // A scroll puts the keyboard away: the list is what you're reading now (user test 2026-11-07).
            .scrollDismissesKeyboard(.immediately)
            // The step's main button stays in reach at the bottom while the stops scroll (user test 2026-11-07, run
            // 2: "Add to trips" was cut in half by the bottom edge, then scrolled away).
            .safeAreaInset(edge: .bottom, spacing: 0) {
                if let title = action.title {
                    Button(title) { action.run?() }
                        .buttonStyle(.clack(.primary, wide: true))
                        .disabled(!action.enabled)
                        .padding(.horizontal, 16).padding(.top, 8).padding(.bottom, 8)
                        .background(Ink.surface)
                }
            }
        }
        .environment(action)
        .background(Ink.surface)
        .presentationCornerRadius(Radius.sheet)
        .presentationBackground(Ink.surface)
    }
}

/// A sheet step's main button, shown pinned by `SheetFrame`.
@MainActor
@Observable
final class SheetAction {
    var title: String?
    var enabled = true
    @ObservationIgnored var run: (() -> Void)?
}

extension View {
    /// Pins this step's main button at the bottom of the sheet while the step shows.
    func sheetAction(_ title: String, enabled: Bool, perform: @escaping () -> Void) -> some View {
        modifier(SheetActionModifier(title: title, enabled: enabled, perform: perform))
    }
}

private struct SheetActionModifier: ViewModifier {
    @Environment(SheetAction.self) private var action: SheetAction?
    let title: String
    let enabled: Bool
    let perform: () -> Void

    func body(content: Content) -> some View {
        content
            .onAppear { apply() }
            .onChange(of: "\(title)|\(enabled)") { apply() }
            .onDisappear {
                guard let action, action.title == title else { return }
                action.title = nil
                action.run = nil
            }
    }

    private func apply() {
        action?.title = title
        action?.enabled = enabled
        action?.run = perform
    }
}

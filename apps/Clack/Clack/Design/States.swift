//
//  States.swift
//  Clack
//

import ClackCore
import ClackDesign
import SwiftUI

/// The one empty state (polish pass 1, DECISIONS C3): what goes here, and one button to put something there. An
/// optional quiet link under it for a second way in.
struct EmptyStateView: View {
    let icon: String
    let title: String
    var message: String?
    var action: (title: String, run: () -> Void)?
    var link: (title: String, run: () -> Void)?

    var body: some View {
        VStack(spacing: Space.m) {
            LucideIcon(name: icon, size: 28)
                .foregroundStyle(Ink.text2)
                .padding(.bottom, Space.xs)
                .accessibilityHidden(true)
            Text(title)
                .clack(.headline).foregroundStyle(Ink.text)
                .multilineTextAlignment(.center)
            if let message {
                Text(message)
                    .clack(.body).foregroundStyle(Ink.text2)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if let action {
                Button(action.title, action: action.run)
                    .buttonStyle(.clack(.primary, wide: true))
                    .padding(.top, Space.s)
            }
            if let link {
                Button(link.title, action: link.run).buttonStyle(LinkButtonStyle())
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Space.xl)
        .accessibilityElement(children: .contain)
    }
}

/// The one failed state (polish pass 1, DECISIONS C3): what happened, what still works, and Try again. A failure is
/// never dressed up as an empty result.
struct ErrorStateView: View {
    let message: String
    /// What still works without the server ("Your saved trips are still here.").
    var stillWorks: String?
    var retry: (() async -> Void)?
    @Environment(L10n.self) private var l10n
    @State private var retrying = false

    var body: some View {
        VStack(alignment: .leading, spacing: Space.s) {
            HStack(alignment: .firstTextBaseline, spacing: Space.s) {
                LucideIcon(name: "wifi-off", size: 16).foregroundStyle(Ink.errorText).accessibilityHidden(true)
                Text(message).clack(.banner).foregroundStyle(Ink.errorText)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if let stillWorks {
                Text(stillWorks).clack(.caption).foregroundStyle(Ink.text2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if let retry {
                Button {
                    retrying = true
                    Task {
                        await retry()
                        retrying = false
                    }
                } label: {
                    HStack(spacing: Space.s) {
                        if retrying { ProgressView().controlSize(.small) }
                        Text(l10n.t("common.tryAgain"))
                    }
                }
                .buttonStyle(.clack(.secondary, small: true))
                .disabled(retrying)
            }
        }
        .padding(Space.m)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Ink.errorBg, in: RoundedRectangle(cornerRadius: Radius.input, style: .continuous))
        .accessibilityElement(children: .contain)
    }
}

/// A short line that says what just happened ("Couldn't delete. Try again.", "Removed · Undo") and goes away by
/// itself (polish pass 1, DECISIONS C4). Any screen shows one through `Toaster` in the environment; RootView draws it
/// above the tab bar.
@MainActor
@Observable
final class Toaster {
    struct Toast: Identifiable, Equatable {
        let id = UUID()
        let text: String
        var isError = false
        var actionTitle: String?
        var action: (() -> Void)?

        static func == (a: Toast, b: Toast) -> Bool { a.id == b.id }
    }

    private(set) var current: Toast?

    func show(_ text: String, isError: Bool = false, actionTitle: String? = nil, action: (() -> Void)? = nil) {
        current = Toast(text: text, isError: isError, actionTitle: actionTitle, action: action)
        AccessibilityNotification.Announcement(text).post()
    }

    func dismiss(_ toast: Toast? = nil) {
        if toast == nil || toast == current { current = nil }
    }
}

/// Draws the Toaster's toast at the bottom, above the tab bar, for 4 s (6 s when it has an action).
struct ToastHost: ViewModifier {
    let toaster: Toaster
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .bottom) {
                if let toast = toaster.current {
                    ToastView(toast: toast) { toaster.dismiss(toast) }
                        .padding(.horizontal, Space.l)
                        .padding(.bottom, Space.s)
                        .transition(Motion.transition(from: .bottom, reduceMotion: reduceMotion))
                        .task(id: toast.id) {
                            try? await Task.sleep(for: .seconds(toast.action == nil ? 4 : 6))
                            toaster.dismiss(toast)
                        }
                }
            }
            .motion(.appear, value: toaster.current)
            .haptic(.error, trigger: toaster.current) { _, new in new?.isError == true }
    }

    private struct ToastView: View {
        let toast: Toaster.Toast
        let close: () -> Void

        var body: some View {
            HStack(spacing: Space.m) {
                Text(toast.text)
                    .clack(.banner)
                    .foregroundStyle(toast.isError ? Ink.errorText : Ink.text)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
                if let title = toast.actionTitle, let action = toast.action {
                    Button(title) {
                        action()
                        close()
                    }
                    .buttonStyle(LinkButtonStyle())
                }
            }
            .padding(.horizontal, Space.l)
            .padding(.vertical, Space.xs)
            .frame(minHeight: 48)
            .background(Ink.surfaceRaised, in: RoundedRectangle(cornerRadius: Radius.input, style: .continuous))
            .hairlineBorder(radius: Radius.input)
            .clackShadow()
            .accessibilityElement(children: .contain)
        }
    }
}

extension View {
    func toastHost(_ toaster: Toaster) -> some View { modifier(ToastHost(toaster: toaster)) }
}

/// A placeholder with the shape of the real thing: `sample` is the real row or card drawn with sample data, redacted
/// and shimmering, so the content that replaces it has the same size and nothing moves after first paint (polish
/// pass 1, DECISIONS C2).
struct Placeholder<Sample: View>: View {
    @ViewBuilder var sample: Sample
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var dim = false

    var body: some View {
        sample
            .redacted(reason: .placeholder)
            .allowsHitTesting(false)
            // A slow breathe instead of a sweep: it reads as "loading" on any shape. Still under Reduce Motion.
            .opacity(dim ? 0.55 : 1)
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) { dim = true }
            }
            .accessibilityHidden(true)
    }
}

/// While something loads: a spinner only once it has taken more than `delay` (300 ms), so a quick load never flashes
/// one (polish pass 1).
struct DelayedSpinner: View {
    var delay: Duration = .milliseconds(300)
    @State private var shown = false

    var body: some View {
        ProgressView()
            .opacity(shown ? 1 : 0)
            .task {
                try? await Task.sleep(for: delay)
                shown = true
            }
    }
}

#Preview("Empty") {
    EmptyStateView(
        icon: "train-front", title: "No trips yet", message: "Add the train you're taking and Clack keeps an eye on it.",
        action: ("Find a train", {}), link: ("Explore live trains", {})
    )
    .padding()
    .environment(L10n())
}

#Preview("Error") {
    ErrorStateView(message: "Couldn't load the board.", stillWorks: "Saved trips still work.", retry: {})
        .padding()
        .environment(L10n())
}

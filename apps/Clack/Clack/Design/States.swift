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

/// The one failed state (polish pass 1, DECISIONS C3): what happened, why, what happens next, and Try again. A failure
/// is never dressed up as an empty result.
///
/// The screen gives its own subject line ("Couldn't load the board."); the kind of failure says the rest, so the
/// person knows whether it's their connection or Clack's server and whether to wait or act: offline (what's saved
/// shows, Clack tries again when the connection is back), the server down or slow (trying again in N s, counting down,
/// with Try now), too many requests (the server's own wait), or given up (still not working, Try again). Without a
/// kind it reads as it always did.
struct ErrorStateView: View {
    let message: String
    /// What still works without the server ("Your saved trips are still here.").
    var stillWorks: String?
    /// What went wrong (`APIError.classify`), when the screen knows.
    var kind: APIError.Kind?
    /// Where the screen's retries stand: a countdown while one is waiting.
    var status: RetryStatus
    var retry: (() async -> Void)?
    @Environment(L10n.self) private var l10n
    @State private var retrying = false

    init(message: String, stillWorks: String? = nil, kind: APIError.Kind? = nil, status: RetryStatus = .idle, retry: (() async -> Void)? = nil) {
        self.message = message
        self.stillWorks = stillWorks
        self.kind = kind ?? status.kind
        self.status = status
        self.retry = retry
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Space.s) {
            HStack(alignment: .firstTextBaseline, spacing: Space.s) {
                LucideIcon(name: FailureText.icon(kind, status: status), size: 16).foregroundStyle(Ink.errorText).accessibilityHidden(true)
                Text(message).clack(.banner).foregroundStyle(Ink.errorText)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if let cause = FailureText.cause(kind, status: status, l10n: l10n) {
                Text(cause).clack(.caption).foregroundStyle(Ink.text)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if let stillWorks {
                Text(stillWorks).clack(.caption).foregroundStyle(Ink.text2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            RetryCountdown(status: status, kind: kind)
            if case .retrying = status {
                // A retry is already waiting: this sends it now rather than starting another.
                Button(l10n.t("retry.tryNow")) { RetryWake.shared.wake() }
                    .buttonStyle(.clack(.secondary, small: true))
            } else if let retry {
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

/// The words and icon for a kind of failure, shared by the error state and the loading that outlasts a retry.
enum FailureText {
    static func icon(_ kind: APIError.Kind?, status: RetryStatus) -> String {
        if case .gaveUp = status { return "triangle-alert" }
        switch kind {
        case nil, .offline, .cancelled: return "wifi-off"
        case .timeout: return "clock"
        case .rateLimited: return "hourglass"
        case .serverDown, .serverError: return "triangle-alert"
        case .notFound, .rejected: return "info"
        }
    }

    /// Why it failed and what Clack does about it, in a line; nil when the screen's own line says it all.
    static func cause(_ kind: APIError.Kind?, status: RetryStatus, l10n: L10n) -> String? {
        if case .gaveUp(let kind) = status, kind.isRetryable { return l10n.t("retry.gaveUp") }
        switch kind {
        case .offline: return l10n.t("retry.cause.offline")
        case .timeout: return l10n.t("retry.cause.timeout")
        case .serverDown: return l10n.t("retry.cause.serverDown")
        case .serverError: return l10n.t("retry.cause.serverError")
        case .rateLimited: return l10n.t("retry.cause.rateLimited")
        case nil, .notFound, .rejected, .cancelled: return nil
        }
    }
}

/// "Trying again in 12 s", counting down each second while a retry waits.
struct RetryCountdown: View {
    let status: RetryStatus
    var kind: APIError.Kind?
    @Environment(L10n.self) private var l10n

    var body: some View {
        if case .retrying(_, let next, let retryKind) = status {
            // Offline, the cause line already says it: the wait ends when the phone is back, not on a clock.
            if (kind ?? retryKind) != .offline {
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    let seconds = max(1, Int(next.timeIntervalSince(context.date).rounded(.up)))
                    Text(l10n.t("retry.in", count: seconds)).clack(.caption).foregroundStyle(Ink.text2)
                        .monospacedDigit()
                }
            }
        }
    }
}

/// Loading that grows with the wait: the skeleton first; after 5 s "Still loading…"; after 15 s the screen's own
/// line for why it can take a while ("Danish timetables can take a moment"). While a retry waits, it says that
/// instead, with its countdown, so a slow answer and a failed one never look the same.
struct GrowingWait<Skeleton: View>: View {
    /// The screen's line for a long wait, shown after 15 s.
    var context: String?
    var status: RetryStatus = .idle
    @ViewBuilder var skeleton: Skeleton
    @Environment(L10n.self) private var l10n
    @State private var stage = 0

    static var stillLoadingAfter: Duration { .seconds(5) }
    static var contextAfter: Duration { .seconds(15) }

    var body: some View {
        VStack(alignment: .leading, spacing: Space.s) {
            if status.kind != nil {
                HStack(alignment: .firstTextBaseline, spacing: Space.s) {
                    LucideIcon(name: FailureText.icon(status.kind, status: status), size: 14).foregroundStyle(Ink.text2).accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: Space.xs) {
                        if let cause = FailureText.cause(status.kind, status: status, l10n: l10n) {
                            Text(cause).clack(.caption).foregroundStyle(Ink.text)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        RetryCountdown(status: status)
                    }
                }
                .accessibilityElement(children: .combine)
            } else if stage >= 1 {
                VStack(alignment: .leading, spacing: Space.xs) {
                    Text(l10n.t("loading.still")).clack(.caption).foregroundStyle(Ink.text2)
                    if stage >= 2, let context {
                        Text(context).clack(.caption).foregroundStyle(Ink.text2)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .accessibilityElement(children: .combine)
            }
            skeleton
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .task {
            try? await Task.sleep(for: Self.stillLoadingAfter)
            if Task.isCancelled { return }
            stage = 1
            try? await Task.sleep(for: Self.contextAfter - Self.stillLoadingAfter)
            if Task.isCancelled { return }
            stage = 2
        }
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

    var body: some View {
        // A slow breathe instead of a sweep: it reads as "loading" on any shape. Still under Reduce Motion. The opacity
        // comes from the clock, not a repeating animation, so a layout change can't be animated along with it (the
        // bouncing Live dot, build 86).
        TimelineView(.animation(paused: reduceMotion)) { context in
            let phase = context.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 1.8) / 1.8
            sample
                .redacted(reason: .placeholder)
                .allowsHitTesting(false)
                .opacity(reduceMotion ? 1 : 0.775 + 0.225 * cos(phase * 2 * .pi))
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
    VStack {
        ErrorStateView(message: "Couldn't load the board.", stillWorks: "Saved trips still work.", retry: {})
        ErrorStateView(message: "Couldn't load the board.", status: .retrying(attempt: 2, next: .now.addingTimeInterval(8), kind: .serverDown), retry: {})
        ErrorStateView(message: "Couldn't load the board.", kind: .offline, retry: {})
    }
    .padding()
    .environment(L10n())
}

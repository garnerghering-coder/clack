//
//  SwipeRow.swift
//  Clack
//

import ClackCore
import ClackDesign
import SwiftUI

/// Swipe left on a row for Share and Delete (DESIGN §4: "swipe left = Delete"; owner, build 87: the swipe was never
/// there on the phones in use). iOS 27 has the system's swipe actions outside a `List`, so it gets those; iOS 17–26
/// get this hand-made one, shaped like the system's: the row slides left over the two buttons, rubber-bands past
/// them, snaps open or shut, closes when another row opens or the list scrolls, and ticks once as it opens.
/// The same two actions are VoiceOver actions on the row.
extension View {
    /// `share` is the text the share sheet is given; `delete` is what Delete does (nil: no Delete, as on a journey's
    /// row, whose trains are deleted inside it). `id` tells this row from the others, so only one is open at a time.
    func trailingSwipe(id: String, share: String?, delete: (() -> Void)?) -> some View {
        modifier(TrailingSwipe(id: id, share: share, delete: delete))
    }

    /// The scroll view whose rows use `trailingSwipe`: one row open at a time, and scrolling closes it.
    func swipeRowsContainer() -> some View {
        modifier(SwipeRowsContainer())
    }
}

/// Whether the system's swipe is used (iOS 27). `-handSwipe` (Debug) uses the hand-made one there too, to check it on
/// a simulator, which only has iOS 27.
private var systemSwipe: Bool {
    #if DEBUG
    if CommandLine.arguments.contains("-handSwipe") { return false }
    #endif
    if #available(iOS 27.0, *) { return true }
    return false
}

/// Which row is open (at most one).
@MainActor
@Observable
final class SwipeRowsState {
    var openID: String?
}

extension EnvironmentValues {
    @Entry var swipeRows: SwipeRowsState?
}

private struct SwipeRowsContainer: ViewModifier {
    @State private var rows = SwipeRowsState()

    func body(content: Content) -> some View {
        if #available(iOS 27.0, *), systemSwipe {
            content.swipeActionsContainer()
        } else if #available(iOS 18.0, *) {
            content
                .environment(\.swipeRows, rows)
                .onScrollPhaseChange { _, phase in
                    if phase == .interacting || phase == .decelerating { rows.openID = nil }
                }
        } else {
            content.environment(\.swipeRows, rows)
        }
    }
}

private struct TrailingSwipe: ViewModifier {
    let id: String
    let share: String?
    let delete: (() -> Void)?
    @Environment(L10n.self) private var l10n

    func body(content: Content) -> some View {
        if #available(iOS 27.0, *), systemSwipe {
            content.swipeActions(edge: .trailing, allowsFullSwipe: false) {
                if let share {
                    ShareLink(item: share) { Label(l10n.t("common.share"), systemImage: "square.and.arrow.up") }
                }
                if let delete {
                    Button(role: .destructive, action: delete) { Label(l10n.t("common.delete"), systemImage: "trash") }
                }
            }
        } else {
            content.modifier(HandSwipe(id: id, share: share, delete: delete))
        }
    }
}

/// The swipe for iOS 17–26.
private struct HandSwipe: ViewModifier {
    let id: String
    let share: String?
    let delete: (() -> Void)?
    @Environment(L10n.self) private var l10n
    @Environment(\.swipeRows) private var rows
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// How far the row has slid (negative: to the left).
    @State private var offset: CGFloat = 0
    /// Where the row was when this drag began.
    @State private var start: CGFloat?
    /// Which way this drag goes, decided on its first movement: a vertical one is the scroll view's.
    @State private var axis: Axis?
    /// The finger is down on a drag; false again when it ends or the system cancels it (a scroll taking over).
    @GestureState private var dragging = false
    @State private var sharing = false
    @State private var opens = 0
    @State private var openNow = false
    /// The row's own tap is off from a sideways drag's start until just after it ends: the row's link otherwise
    /// opened the trip on the finger's lift (simulator check, build 87).
    @State private var blockTap = false

    private static let buttonWidth: CGFloat = 74
    private static let gap: CGFloat = Space.s

    private var count: Int { (share == nil ? 0 : 1) + (delete == nil ? 0 : 1) }
    /// How far the row slides to show the buttons in full.
    private var reveal: CGFloat { CGFloat(count) * (Self.buttonWidth + Self.gap) }

    func body(content: Content) -> some View {
        if count == 0 {
            content
        } else {
            content
                .disabled(blockTap)
                .offset(x: offset)
                // Open, a tap on the row closes it rather than opening the trip (as the system's does).
                .overlay {
                    if offset < 0 {
                        Color.clear.contentShape(Rectangle())
                            .offset(x: offset)
                            .onTapGesture { settle(open: false) }
                            .accessibilityHidden(true)
                    }
                }
                .background(alignment: .trailing) { buttons }
                .simultaneousGesture(drag)
                .onChange(of: dragging) { _, down in
                    // The drag ended without `onEnded` (the scroll view took the touch): snap to the nearer end.
                    if !down, axis == .horizontal { finish(predicted: offset) }
                    if !down { axis = nil; start = nil; releaseTap() }
                }
                .onChange(of: rows?.openID) { _, open in
                    if open != id, offset != 0, axis == nil { settle(open: false) }
                }
                .haptic(.selection, trigger: opens)
                .accessibilityActions {
                    if share != nil { Button(l10n.t("common.share")) { sharing = true } }
                    if let delete { Button(l10n.t("detail.delete"), action: delete) }
                }
                .sheet(isPresented: $sharing) {
                    if let share { ActivitySheet(items: [share]).presentationDetents([.medium, .large]) }
                }
        }
    }

    /// Share (neutral) and Delete (red), each as wide as its share of the slide, so they grow with the finger.
    private var buttons: some View {
        let shown = max(0, -offset)
        let width = max(0, (shown - CGFloat(count) * Self.gap) / CGFloat(count))
        return HStack(spacing: Self.gap) {
            if share != nil {
                swipeButton(l10n.t("common.share"), icon: "square.and.arrow.up", fill: Ink.fillSoft, ink: Ink.text, width: width) {
                    settle(open: false)
                    sharing = true
                }
            }
            if let delete {
                // White on the destructive red, as the system's Delete is.
                swipeButton(l10n.t("common.delete"), icon: "trash", fill: Ink.veryLate, ink: .white, width: width) {
                    settle(open: false)
                    delete()
                }
            }
        }
        .padding(.leading, Self.gap)
        .frame(width: shown, alignment: .trailing)
        .clipped()
        .opacity(shown > 1 ? 1 : 0)
        .accessibilityHidden(true)
    }

    private func swipeButton(_ title: String, icon: String, fill: Color, ink: Color, width: CGFloat, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: Space.xs) {
                Image(systemName: icon).font(.body.weight(.semibold))
                Text(title).clack(.micro).lineLimit(1).minimumScaleFactor(0.7)
            }
            .foregroundStyle(ink)
            .opacity(width > 44 ? 1 : 0)
            .frame(width: width)
            .frame(maxHeight: .infinity)
            .background(fill, in: RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var drag: some Gesture {
        DragGesture(minimumDistance: 12, coordinateSpace: .local)
            .updating($dragging) { _, state, _ in state = true }
            .onChanged { value in
                if axis == nil {
                    let dx = abs(value.translation.width), dy = abs(value.translation.height)
                    // Only a clearly sideways drag is the row's; anything else is a scroll, and closes an open row.
                    if dx > dy * 1.4 {
                        axis = .horizontal
                        blockTap = true
                        start = offset
                        rows?.openID = id
                    } else {
                        axis = .vertical
                        if rows?.openID != nil { rows?.openID = nil }
                    }
                }
                guard axis == .horizontal else { return }
                offset = rubberBand((start ?? 0) + value.translation.width)
            }
            .onEnded { value in
                guard axis == .horizontal else { return }
                finish(predicted: (start ?? 0) + value.predictedEndTranslation.width)
                axis = nil
                start = nil
            }
    }

    private func releaseTap() {
        Task {
            try? await Task.sleep(for: .milliseconds(350))
            if axis == nil { blockTap = false }
        }
    }

    /// Past either end the row follows the finger less and less.
    private func rubberBand(_ x: CGFloat) -> CGFloat {
        if x > 0 { return pow(x, 0.6) }
        if x < -reveal { return -reveal - pow(-reveal - x, 0.7) }
        return x
    }

    private func finish(predicted: CGFloat) {
        settle(open: predicted < -reveal / 2)
    }

    private func settle(open: Bool) {
        withAnimation(reduceMotion ? Motion.reduced : .snappy(duration: 0.28)) { offset = open ? -reveal : 0 }
        if open {
            rows?.openID = id
            if !openNow { opens += 1 }
        } else if rows?.openID == id {
            rows?.openID = nil
        }
        openNow = open
    }
}

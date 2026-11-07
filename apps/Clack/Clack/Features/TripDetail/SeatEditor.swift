//
//  SeatEditor.swift
//  Clack
//

import ClackCore
import ClackDesign
import SwiftUI

/// "Your seat" in a trip's details: the car and seat as on your ticket, typed in or read off it. Saved with
/// `PATCH /api/legs/:id` when you tap Save; a field emptied clears it.
struct SeatEditor: View {
    @Environment(AppModel.self) private var app
    @Environment(L10n.self) private var l10n
    let leg: Leg
    /// The trip as the server has it after the change.
    let onSaved: (LegDetail) -> Void
    /// A field got the keyboard: the page scrolls the fields above it.
    var onFocus: () -> Void = {}

    // Filled from the trip when the editor is made, and again only when the saved values change while neither field
    // is being typed in: not on every appear, which wiped what was typed when the page rebuilt (user test 2026-11-07,
    // run 2: "23" gone after the keyboard closed).
    @State private var coach: String
    @State private var seat: String

    init(leg: Leg, onSaved: @escaping (LegDetail) -> Void, onFocus: @escaping () -> Void = {}) {
        self.leg = leg
        self.onSaved = onSaved
        self.onFocus = onFocus
        _coach = State(initialValue: leg.coach ?? "")
        _seat = State(initialValue: leg.seat ?? "")
    }
    @State private var saving = false
    @State private var failed = false
    @FocusState private var focus: Field?

    private enum Field { case coach, seat }

    private var patch: LegPatch? { Seat.patch(coach: coach, seat: seat, was: leg) }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(l10n.t("seat.title")).clack(.sectionHeader).foregroundStyle(Ink.text2)
            HStack(spacing: 12) {
                field(l10n.t("seat.coachLabel"), text: $coach, field: .coach)
                field(l10n.t("seat.seatLabel"), text: $seat, field: .seat)
            }
            if patch != nil {
                Button(l10n.t("seat.save")) { Task { await save() } }
                    .buttonStyle(.clack(.primary, small: true))
                    .disabled(saving)
            }
            if failed { Text(l10n.t("seat.failed")).clack(.caption).foregroundStyle(Ink.veryLateInk) }
            // Said once it is saved (and shown on the trip's header from then on).
            if savedNote, patch == nil, !failed { Text(l10n.t("seat.savedNote")).clack(.caption).foregroundStyle(Ink.onTimeInk) }
        }
        .onChange(of: leg.id) { _, _ in reset() }
        .onChange(of: leg.coach) { _, _ in if focus == nil { reset() } }
        .onChange(of: leg.seat) { _, _ in if focus == nil { reset() } }
        // Leaving the fields saves what was typed, so nothing depends on reaching a button.
        .onChange(of: focus) { was, now in
            if was == nil, now != nil { onFocus() }
            if was != nil, now == nil, patch != nil { Task { await save() } }
        }
    }

    private func field(_ label: String, text: Binding<String>, field: Field) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).clack(.caption).foregroundStyle(Ink.text2)
            TextField("", text: text, prompt: Text(Format.unknown).foregroundStyle(Ink.text3))
                .focused($focus, equals: field)
                .textInputAutocapitalization(.characters)
                .autocorrectionDisabled()
                // Digits first (a car is "5", a seat "23"; letters are a tap away for "12A"), with the keyboard's own
                // Done key, which saves (user test 2026-11-07: full QWERTY with caps, no Done). No bar above the
                // keyboard: on iOS 26 it floats as a glass pill over the seat field (run 2); the page scrolls the
                // fields and the Save button above the keyboard instead.
                .keyboardType(.numbersAndPunctuation)
                .submitLabel(.done)
                .onSubmit { Task { await save(); focus = nil } }
                .clack(.body).monospacedDigit().foregroundStyle(Ink.text)
                .padding(.vertical, 8).padding(.horizontal, 12)
                .frame(minHeight: 44)
                .background(Ink.surfaceRaised, in: RoundedRectangle(cornerRadius: Radius.input, style: .continuous))
                .hairlineBorder(radius: Radius.input)
                .onChange(of: text.wrappedValue) { _, new in
                    if new.count > Seat.maxLength { text.wrappedValue = String(new.prefix(Seat.maxLength)) }
                }
                .accessibilityLabel(label)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func reset() {
        coach = leg.coach ?? ""
        seat = leg.seat ?? ""
    }

    @State private var savedNote = false

    private func save() async {
        guard let patch, !saving else { return }
        saving = true
        failed = false
        do {
            let updated = try await app.client.updateLeg(leg.id, patch)
            focus = nil
            onSaved(updated)
            savedNote = true
            AccessibilityNotification.Announcement(l10n.t("seat.saved")).post()
        } catch {
            failed = true
        }
        saving = false
    }
}

//
//  EditManualTripSheet.swift
//  Clack
//

import ClackCore
import ClackDesign
import SwiftUI

/// Correcting a trip added by hand (user test 2026-11-07: "a log you can't correct is not a log"): its day, times,
/// operator, number and kind. The stations stay; a different route is another trip. Saved with `PATCH /api/legs/:id`.
struct EditManualTripSheet: View {
    @Environment(AppModel.self) private var app
    @Environment(L10n.self) private var l10n
    @Environment(\.dismiss) private var dismiss
    let leg: LegDetail
    let onSaved: (LegDetail) -> Void

    @State private var day = Date.now
    @State private var dep = Date.now
    @State private var arr = Date.now
    @State private var operatorId = ""
    @State private var trainNumber = ""
    @State private var category = "regional"
    @State private var saving = false
    @State private var error: String?
    @FocusState private var numberFocused: Bool

    private static let categories = ["intercity", "regional", "commuter", "night", "heritage"]
    private static let utc = TimeZone(identifier: "UTC") ?? .gmt

    var body: some View {
        let l = leg.leg
        NavigationStack {
            Form {
                Section {
                    Text("\(l.origin?.name ?? "") → \(l.destination?.name ?? "")").font(.headline)
                    Text(l10n.t("edit.stationsStay")).font(.footnote).foregroundStyle(.secondary)
                }
                Section(l10n.t("edit.when")) {
                    DatePicker(l10n.t("edit.day"), selection: $day, in: ...Date.now.addingTimeInterval(366 * 86400), displayedComponents: .date)
                    DatePicker(l10n.t("manual.dep"), selection: $dep, displayedComponents: .hourAndMinute)
                    DatePicker(l10n.t("manual.arr"), selection: $arr, displayedComponents: .hourAndMinute)
                    Text(l10n.t("manual.timesNote")).font(.footnote).foregroundStyle(.secondary)
                }
                .environment(\.timeZone, Self.utc)
                Section(l10n.t("edit.train")) {
                    HStack {
                        Text(l10n.t("manual.operator"))
                        Spacer()
                        OperatorPickerButton(selection: $operatorId)
                    }
                    HStack {
                        Text(l10n.t("manual.number"))
                        Spacer()
                        TextField("", text: $trainNumber)
                            .keyboardType(.numberPad).multilineTextAlignment(.trailing)
                            .focused($numberFocused)
                            .frame(maxWidth: 140)
                            .onChange(of: trainNumber) { _, new in if new.count > 10 { trainNumber = String(new.prefix(10)) } }
                    }
                    Picker(l10n.t("edit.kind"), selection: $category) {
                        ForEach(Self.categories, id: \.self) { c in Text(l10n.t("manual.kinds.\(c)")).tag(c) }
                    }
                }
                if let error { Section { Text(error).foregroundStyle(.red) } }
            }
            .tint(Ink.accent)
            .navigationTitle(l10n.t("detail.menuEdit"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button(l10n.t("common.cancel")) { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button(l10n.t("common.save")) { Task { await save() } }.disabled(saving) }
                ToolbarItemGroup(placement: .keyboard) {
                    if numberFocused {
                        Spacer()
                        Button(l10n.t("common.done")) { numberFocused = false }
                    }
                }
            }
            .onAppear(perform: load)
        }
    }

    /// The trip as saved, in the wheels: the day and the local times at each end.
    private func load() {
        let l = leg.leg
        operatorId = l.operator?.id ?? ""
        trainNumber = l.trainNumber ?? ""
        category = Self.categories.contains(l.category ?? "") ? (l.category ?? "regional") : "regional"
        if let iso = l.serviceDate, let noon = Format.isoToNoonMs(iso) { day = Date(timeIntervalSince1970: noon / 1000) }
        dep = Self.clock(l.schedDep?.ms, tz: l.origin?.tz ?? Format.defaultZone)
        arr = Self.clock(l.schedArr?.ms, tz: l.destination?.tz ?? Format.defaultZone)
    }

    /// The local wall-clock time of an instant as a UTC date on 1970-01-01, for the hour-and-minute wheel.
    private static func clock(_ ms: Double?, tz: String) -> Date {
        guard let ms else { return Date(timeIntervalSince1970: 8 * 3600) }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: tz) ?? .current
        let parts = calendar.dateComponents([.hour, .minute], from: Date(timeIntervalSince1970: ms / 1000))
        return Date(timeIntervalSince1970: Double((parts.hour ?? 0) * 3600 + (parts.minute ?? 0) * 60))
    }

    private static func hhmm(_ d: Date) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = utc
        return String(format: "%02d:%02d", calendar.component(.hour, from: d), calendar.component(.minute, from: d))
    }

    private func save() async {
        saving = true
        error = nil
        let patch = LegPatch(
            date: Format.localDate(day.timeIntervalSince1970 * 1000, tz: "UTC"), dep: Self.hhmm(dep), arr: Self.hhmm(arr),
            operatorId: .some(operatorId.isEmpty ? nil : operatorId), trainNumber: .some(trainNumber.isEmpty ? nil : trainNumber), category: category
        )
        do {
            let updated = try await app.client.updateLeg(leg.id, patch)
            onSaved(updated)
            dismiss()
        } catch {
            self.error = (error as? APIError)?.message ?? error.localizedDescription
        }
        saving = false
    }
}

//
//  LiveAddSheet.swift
//  Clack
//

import ClackCore
import ClackDesign
import SwiftUI

/// Adding a train no timetable of ours has, from the live feed's own stop list (owner, 2026-11-01): pick where you got
/// on, then where you got off; it is saved as a trip "from live data" with the feed's times and platforms.
struct LiveAddSheet: View {
    @Environment(AppModel.self) private var app
    @Environment(L10n.self) private var l10n
    @Environment(Router.self) private var router
    @Environment(\.dismiss) private var dismiss
    let trainId: String
    let title: String
    let stops: [LiveTrainStop]
    /// The zone the times are shown in (the stops don't carry one).
    let tz: String
    @State private var board: LiveTrainStop?
    @State private var saving = false
    @State private var error: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    Text(title).clack(.headline).foregroundStyle(Ink.text)
                    Text(l10n.t(board == nil ? "liveAdd.pickBoard" : "liveAdd.pickAlight")).clack(.body).foregroundStyle(Ink.text2)
                    let choices = board.map { b in stops.filter { $0.seq > b.seq } } ?? Array(stops.dropLast())
                    ForEach(choices) { stop in
                        Button { Task { await pick(stop) } } label: {
                            HStack {
                                Text(stop.name).clack(.rowTitle).foregroundStyle(Ink.text)
                                Spacer()
                                Text(Format.time(board == nil ? (stop.dep ?? stop.arr) : (stop.arr ?? stop.dep), tz: tz, clock: app.settings.clock))
                                    .clack(.body).monospacedDigit().foregroundStyle(Ink.text2)
                                if let p = stop.platform { PlatformTag(platform: p) }
                            }
                            .padding(.vertical, 8)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .disabled(saving)
                    }
                    if let error { Text(error).clack(.caption).foregroundStyle(Ink.errorText) }
                    Text(l10n.t("liveAdd.note")).clack(.caption).foregroundStyle(Ink.text2)
                }
                .padding(16)
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button(l10n.t("common.cancel")) { dismiss() } }
                if board != nil {
                    ToolbarItem(placement: .navigation) { Button(l10n.t("liveAdd.back")) { board = nil } }
                }
            }
        }
    }

    private func pick(_ stop: LiveTrainStop) async {
        guard let board else { self.board = stop; return }
        saving = true
        defer { saving = false }
        do {
            let leg = try await app.client.addLiveTrain(trainId, from: board.stationId, to: stop.stationId)
            app.tripsChanged()
            dismiss()
            router.push(.trip(leg.id))
        } catch let e as APIError {
            error = e.message
        } catch {
            self.error = l10n.t("liveAdd.failed")
        }
    }
}

/// "Add to trips" for a live train no timetable of ours has: opens `LiveAddSheet` when the feed has its stops.
struct LiveAddButton: View {
    @Environment(L10n.self) private var l10n
    let trainId: String
    let title: String
    let stops: [LiveTrainStop]
    let tz: String
    @State private var open = false

    var body: some View {
        Button { open = true } label: {
            HStack(spacing: 8) {
                LucideIcon(name: "plus", size: 16)
                Text(l10n.t("liveMap.plan")).lineLimit(1).minimumScaleFactor(0.85)
            }
        }
        .buttonStyle(.clack(.primary, wide: true))
        .disabled(stops.count < 2)
        .sheet(isPresented: $open) { LiveAddSheet(trainId: trainId, title: title, stops: stops, tz: tz) }
    }
}

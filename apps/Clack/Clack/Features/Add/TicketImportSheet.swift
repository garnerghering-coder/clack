//
//  TicketImportSheet.swift
//  Clack
//

import ClackCore
import ClackDesign
import SwiftUI

/// A ticket file handed to Clack from the share sheet ("Open in Clack").
struct TicketFile: Identifiable, Hashable {
    let id = UUID()
    /// A copy in the app's temporary folder, deleted once it has been read.
    let url: URL
    let name: String
}

/// The trains on a ticket, each looked up in the timetable. Only the trips you choose are saved; the file itself is
/// read on the phone and never sent anywhere.
@MainActor
@Observable
final class TicketImportModel {
    enum Phase { case reading, unreadable, ready, saving, done }
    /// `addSeat`: the train is already saved and the ticket says where you sit, which the trip doesn't have yet.
    /// `notCovered`: a station of the leg isn't in Clack (a DB ticket's German legs); `noTimetable`: no timetable covers
    /// the day. Neither is imported, and the row says why.
    enum State { case matching, found, notFound, notCovered, noTimetable, already, addSeat, added, seatAdded, failed }

    struct Row: Identifiable {
        let train: TicketTrain
        var state: State = .matching
        var match: TripResult?
        /// The trip already saved for this train, when there is one.
        var saved: Leg?
        var selected = false
        var id: String { train.id }
        var choosable: Bool { state == .found || state == .addSeat }
    }

    private(set) var phase = Phase.reading
    private(set) var rows: [Row] = []

    var chosen: Int { rows.filter { $0.selected && $0.choosable }.count }
    /// Only seats to add, no new trains: the button says so.
    var onlySeats: Bool { !rows.contains { $0.selected && $0.state == .found } }

    func toggle(_ id: String) {
        guard let i = rows.firstIndex(where: { $0.id == id }), rows[i].choosable else { return }
        rows[i].selected.toggle()
    }

    func load(_ file: TicketFile, _ client: APIClient) async {
        let data = try? Data(contentsOf: file.url)
        try? FileManager.default.removeItem(at: file.url)
        let trains = data.map { TicketReader.trains(inFile: $0, name: file.name) } ?? []
        guard !trains.isEmpty else {
            phase = .unreadable
            return
        }
        rows = trains.map { Row(train: $0) }
        phase = .ready
        let have = (try? await client.legs()) ?? []
        await withTaskGroup(of: (String, TripResult?, State?).self) { group in
            for train in trains {
                group.addTask {
                    let found = await Self.find(train, client)
                    return (train.id, found.match, found.missing)
                }
            }
            for await (id, match, missing) in group {
                guard let i = rows.firstIndex(where: { $0.id == id }) else { continue }
                rows[i].match = match
                if let match {
                    let saved = have.first { $0.timetableTripKey == match.key && $0.serviceDate == match.serviceDate }
                    rows[i].saved = saved
                    if let saved {
                        let train = rows[i].train
                        let seatNews = Seat.patch(coach: train.coach ?? saved.coach, seat: train.seat ?? saved.seat, was: saved) != nil
                        rows[i].state = seatNews ? .addSeat : .already
                        rows[i].selected = seatNews
                    } else {
                        rows[i].state = .found
                        rows[i].selected = true
                    }
                } else {
                    rows[i].state = missing ?? .notFound
                }
            }
        }
    }

    /// Search the two stations on the date (with an arrow between them, so each printed name only has to be a fair
    /// match), then the same with the ticket's train number. Waits while the server fetches an older day's timetable.
    /// Without a match, `missing` says why when it's known: a station Clack doesn't have (on a DB ticket, a leg inside
    /// Germany), or a day no timetable covers.
    private nonisolated static func find(_ train: TicketTrain, _ client: APIClient) async -> (match: TripResult?, missing: State?) {
        let first = await search("\(train.from) → \(train.to)", train, client)
        if let hit = first.match { return (hit, nil) }
        // A station Clack doesn't know: searching by the number could only find some other train of that number.
        let known = first.response.map { $0.interpretation.from != nil && $0.interpretation.to != nil } ?? true
        if known, let number = train.trainNumber, let hit = await search("\(number) \(train.from) → \(train.to)", train, client).match { return (hit, nil) }
        guard let response = first.response else { return (nil, nil) }
        if train.issuer == .db && (response.interpretation.from == nil || response.interpretation.to == nil) { return (nil, .notCovered) }
        if response.outsideTimetable || response.history == "unavailable" { return (nil, .noTimetable) }
        return (nil, nil)
    }

    /// One search, asked again while the day is being fetched ("loading", every 3 s) or after a failure (every 15 s, or
    /// a network error), for up to three minutes, like adding a train does.
    private nonisolated static func search(_ text: String, _ train: TicketTrain, _ client: APIClient) async -> (match: TripResult?, response: SearchResponse?) {
        let started = Date.now
        while Date.now.timeIntervalSince(started) < 180 {
            guard let response = try? await client.search(text, date: train.date) else {
                try? await Task.sleep(for: .seconds(5))
                continue
            }
            switch response.history {
            case "loading": try? await Task.sleep(for: .seconds(3))
            case "failed": try? await Task.sleep(for: .seconds(15))
            default: return (TicketReader.pick(response.results ?? [], for: train), response)
            }
        }
        return (nil, nil)
    }

    func save(_ client: APIClient) async {
        phase = .saving
        for i in rows.indices where rows[i].selected && rows[i].choosable {
            guard let m = rows[i].match else { continue }
            let train = rows[i].train
            do {
                if rows[i].state == .addSeat, let saved = rows[i].saved {
                    // What the ticket says, over what the trip had; a half the ticket doesn't print is left as it was.
                    if let patch = Seat.patch(coach: train.coach ?? saved.coach, seat: train.seat ?? saved.seat, was: saved) {
                        _ = try await client.updateLeg(saved.id, patch)
                    }
                    rows[i].state = .seatAdded
                } else {
                    _ = try await client.createLeg(CreateLegBody(
                        tripKey: m.key, serviceDate: m.serviceDate, fromSeq: m.from.seq, toSeq: m.to.seq,
                        coach: Seat.clean(train.coach), seat: Seat.clean(train.seat)
                    ))
                    rows[i].state = .added
                }
            } catch let error as APIError where error.status == 409 {
                rows[i].state = .already
            } catch {
                rows[i].state = .failed
            }
            rows[i].selected = false
        }
        phase = .done
        Usage.shared.count(.feature, "ticket.import")
    }
}

struct TicketImportSheet: View {
    @Environment(AppModel.self) private var app
    @Environment(L10n.self) private var l10n
    @Environment(Router.self) private var router
    let file: TicketFile
    @State private var model = TicketImportModel()

    var body: some View {
        SheetFrame(title: l10n.t("ticketImport.title"), onClose: { router.ticketFile = nil }) {
            content
        }
        .task { await model.load(file, app.client) }
        .sensoryFeedback(.success, trigger: model.phase == .done)
        // Saved: show it in Trips and close the sheet by itself, after a moment to see what happened.
        .task(id: model.phase == .done) {
            guard model.phase == .done else { return }
            app.tripsChanged()
            try? await Task.sleep(for: .milliseconds(800))
            guard !Task.isCancelled else { return }
            router.ticketFile = nil
            router.tab = .trips
        }
    }

    @ViewBuilder
    private var content: some View {
        switch model.phase {
        case .reading:
            Skeleton(height: 120)
        case .unreadable:
            VStack(alignment: .leading, spacing: 16) {
                Text(l10n.t("ticketImport.unreadable")).clack(.body).foregroundStyle(Ink.text2)
                Button(l10n.t("ticketImport.addByHand")) {
                    router.ticketFile = nil
                    router.openAdd()
                }
                .buttonStyle(ClackButtonStyle(kind: .primary, wide: true))
            }
        case .ready, .saving, .done:
            VStack(alignment: .leading, spacing: 12) {
                ForEach(model.rows) { row in rowView(row) }
                actions
            }
        }
    }

    private func rowView(_ row: TicketImportModel.Row) -> some View {
        let m = row.match
        let from = m?.from.name ?? row.train.from
        let to = m?.to.name ?? row.train.to
        // The ticket's own times ("07:14", as printed) when no timetable match gives the real ones.
        let times: Text = m.map {
            TimePair.text(.init(time: $0.from.time, tz: $0.from.tz), .init(time: $0.to.time, tz: $0.to.tz), clock: app.settings.clock)
        } ?? Text(row.train.dep + (row.train.arr.map { TimePair.separator + $0 } ?? "")).monospacedDigit()
        let train = Format.join([
            row.train.operatorName, (m?.trainNumber ?? row.train.trainNumber).map { l10n.t("add.trainNumber", ["number": $0]) },
            Seat.label(l10n, coach: row.train.coach, seat: row.train.seat),
        ])
        return Button {
            model.toggle(row.id)
        } label: {
            HStack(alignment: .top, spacing: 12) {
                LucideIcon(name: row.selected ? "square-check" : "square", size: 22)
                    .foregroundStyle(row.selected ? Ink.accentInk : Ink.text3)
                    .opacity(row.choosable || row.selected ? 1 : 0.4)
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(from) → \(to)").clack(.rowTitle).foregroundStyle(Ink.text).multilineTextAlignment(.leading)
                    (times + Text(Format.separator + Format.day(Format.isoToNoonMs(row.train.date) ?? 0, tz: m?.from.tz ?? "Europe/Stockholm", language: app.settings.language)))
                        .clack(.caption).monospacedDigit().foregroundStyle(Ink.text2)
                    if !train.isEmpty { Text(train).clack(.caption).foregroundStyle(Ink.text2) }
                    Text(statusText(row)).clack(.caption).fontWeight(.semibold).foregroundStyle(statusColor(row.state))
                }
                Spacer(minLength: 0)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Ink.surface, in: RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
            .hairlineBorder(radius: Radius.card)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(row.selected ? .isSelected : [])
    }

    private func statusText(_ row: TicketImportModel.Row) -> String {
        let seat = Seat.label(l10n, coach: row.train.coach, seat: row.train.seat) ?? ""
        return switch row.state {
        case .matching: l10n.t("ticketImport.matching")
        case .found: l10n.t("ticketImport.found")
        case .notFound: l10n.t("ticketImport.notFound")
        case .notCovered: l10n.t("ticketImport.notCovered")
        case .noTimetable: l10n.t("ticketImport.noTimetable")
        case .already: l10n.t("ticketImport.already")
        case .addSeat: l10n.t("ticketImport.addSeat", ["seat": seat])
        case .seatAdded: l10n.t("ticketImport.seatAdded", ["seat": seat])
        case .added: l10n.t("ticketImport.added")
        case .failed: l10n.t("ticketImport.failed")
        }
    }

    private func statusColor(_ state: TicketImportModel.State) -> Color {
        switch state {
        case .added, .seatAdded: Ink.onTimeInk
        case .failed, .notFound: Ink.text2
        default: Ink.text2
        }
    }

    @ViewBuilder
    private var actions: some View {
        if model.phase != .done {
            Button(model.chosen > 0 && model.onlySeats ? l10n.t("seat.save") : l10n.t("ticketImport.add", count: model.chosen)) {
                Task { await model.save(app.client) }
            }
            .buttonStyle(ClackButtonStyle(kind: .primary, wide: true))
            .disabled(model.chosen == 0 || model.phase == .saving)
            if model.rows.contains(where: { $0.state == .notFound }) {
                Button(l10n.t("ticketImport.addByHand")) {
                    router.ticketFile = nil
                    router.openAdd()
                }
                .buttonStyle(LinkButtonStyle())
                .frame(maxWidth: .infinity)
            }
        }
    }
}

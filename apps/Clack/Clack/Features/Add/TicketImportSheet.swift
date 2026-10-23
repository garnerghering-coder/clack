//
//  TicketImportSheet.swift
//  Clack
//

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
    enum State { case matching, found, notFound, already, added, failed }

    struct Row: Identifiable {
        let train: TicketTrain
        var state: State = .matching
        var match: TripResult?
        var selected = false
        var id: String { train.id }
    }

    private(set) var phase = Phase.reading
    private(set) var rows: [Row] = []

    var chosen: Int { rows.filter { $0.selected && $0.state == .found }.count }

    func toggle(_ id: String) {
        guard let i = rows.firstIndex(where: { $0.id == id }), rows[i].state == .found else { return }
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
        await withTaskGroup(of: (String, TripResult?).self) { group in
            for train in trains {
                group.addTask { (train.id, await Self.find(train, client)) }
            }
            for await (id, match) in group {
                guard let i = rows.firstIndex(where: { $0.id == id }) else { continue }
                rows[i].match = match
                if let match {
                    let saved = have.contains { $0.timetableTripKey == match.key && $0.serviceDate == match.serviceDate }
                    rows[i].state = saved ? .already : .found
                    rows[i].selected = !saved
                } else {
                    rows[i].state = .notFound
                }
            }
        }
    }

    /// Search the two stations on the date, waiting while the server fetches an older day's timetable.
    private nonisolated static func find(_ train: TicketTrain, _ client: APIClient) async -> TripResult? {
        for attempt in 0..<25 {
            guard let response = try? await client.search("\(train.from) \(train.to)", date: train.date) else { return nil }
            if response.history == "loading", attempt < 24 {
                try? await Task.sleep(for: .seconds(3))
                continue
            }
            return TicketReader.pick(response.results ?? [], for: train)
        }
        return nil
    }

    func save(_ client: APIClient) async {
        phase = .saving
        for i in rows.indices where rows[i].selected && rows[i].state == .found {
            guard let m = rows[i].match else { continue }
            do {
                _ = try await client.createLeg(CreateLegBody(tripKey: m.key, serviceDate: m.serviceDate, fromSeq: m.from.seq, toSeq: m.to.seq))
                rows[i].state = .added
            } catch let error as APIError where error.status == 409 {
                rows[i].state = .already
            } catch {
                rows[i].state = .failed
            }
            rows[i].selected = false
        }
        phase = .done
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
    }

    @ViewBuilder
    private var content: some View {
        switch model.phase {
        case .reading:
            Skeleton(height: 120)
        case .unreadable:
            VStack(alignment: .leading, spacing: 14) {
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
        let times = m.map { "\(Format.time($0.from.time, tz: $0.from.tz, clock: app.settings.clock)) → \(Format.time($0.to.time, tz: $0.to.tz, clock: app.settings.clock))" }
            ?? "\(row.train.dep)\(row.train.arr.map { " → \($0)" } ?? "")"
        let train = [row.train.operatorName, (m?.trainNumber ?? row.train.trainNumber).map { l10n.t("add.trainNumber", ["number": $0]) }]
            .compactMap { $0 }.joined(separator: " · ")
        return Button {
            model.toggle(row.id)
        } label: {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: row.selected ? "checkmark.square.fill" : "square")
                    .font(.system(size: 22))
                    .foregroundStyle(row.selected ? Ink.accent : Ink.text3)
                    .opacity(row.state == .found || row.selected ? 1 : 0.4)
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(from) → \(to)").clack(.rowTitle).foregroundStyle(Ink.text).multilineTextAlignment(.leading)
                    Text("\(times) · \(Format.day(Format.isoToNoonMs(row.train.date) ?? 0, tz: m?.from.tz ?? "Europe/Stockholm", language: app.settings.language))")
                        .clack(.caption).monospacedDigit().foregroundStyle(Ink.text2)
                    if !train.isEmpty { Text(train).clack(.caption).foregroundStyle(Ink.text2) }
                    Text(statusText(row.state)).clack(.caption).fontWeight(.semibold).foregroundStyle(statusColor(row.state))
                }
                Spacer(minLength: 0)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Ink.surface, in: RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
            .hairlineBorder(radius: Radius.card)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(row.selected ? .isSelected : [])
    }

    private func statusText(_ state: TicketImportModel.State) -> String {
        switch state {
        case .matching: l10n.t("ticketImport.matching")
        case .found: l10n.t("ticketImport.found")
        case .notFound: l10n.t("ticketImport.notFound")
        case .already: l10n.t("ticketImport.already")
        case .added: l10n.t("ticketImport.added")
        case .failed: l10n.t("ticketImport.failed")
        }
    }

    private func statusColor(_ state: TicketImportModel.State) -> Color {
        switch state {
        case .added: Ink.onTimeInk
        case .failed, .notFound: Ink.text2
        default: Ink.text2
        }
    }

    @ViewBuilder
    private var actions: some View {
        if model.phase == .done {
            Button(l10n.t("common.done")) {
                router.ticketFile = nil
                router.tab = .trips
            }
            .buttonStyle(ClackButtonStyle(kind: .primary, wide: true))
        } else {
            Button(l10n.t("ticketImport.add", count: model.chosen)) {
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

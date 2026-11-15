//
//  Disruption.swift
//  Clack
//

import Foundation

/// Disruptions on a saved trip (owner, 2026-10-22): what happened, what it does to the rest of the journey, how urgent
/// it is right now, and what you may be entitled to. Deterministic rules over the trip's own data; no guessing.
/// A port of `packages/shared/src/disruption.ts`. Times are epoch milliseconds.
public nonisolated enum DisruptionKind: String, Sendable, Hashable {
    /// The train doesn't run on any of your part of the route.
    case canceled
    /// It starts later on your part than where you get on (`PartialRun.runsFrom`, known to start there).
    case startsLater = "starts_later"
    /// It ends before where you get off (`PartialRun.runsTo`, known to end there).
    case endsEarly = "ends_early"
    /// No train on a stretch in the middle of your part (`PartialRun.gaps`).
    case gap
    /// The train runs, but not from where you get on.
    case skipsBoard = "skips_board"
    /// The train runs, but doesn't stop where you get off.
    case skipsAlight = "skips_alight"
    /// Trafikverket says buses replace the train for part of the way.
    case replacement
    /// 15 minutes or more late (expected or actual).
    case delayed
    /// Your change to the next train won't work on current times.
    case connectionMissed = "connection_missed"
    /// Your change is under 5 minutes on current times.
    case connectionAtRisk = "connection_at_risk"
}

/// `actNow`: you need to do something soon. `headsUp`: worth knowing before you go. `info`: for the record.
public nonisolated enum Urgency: String, Sendable, Hashable {
    case actNow = "act_now"
    case headsUp = "heads_up"
    case info
}

public nonisolated struct DisruptionInput: Sendable {
    public var canceled = false
    public var boardCanceled = false
    public var alightCanceled = false
    /// The train runs only part of your way (`Disruption.cancellation(of:)`); wins over the three flags above when given.
    public var partial: PartialRun?
    /// Trafikverket's deviation texts on the stops you travel through.
    public var deviations: [String] = []
    /// Best known delays in minutes (actual, else expected), or nil.
    public var depDelayMin: Int?
    public var arrDelayMin: Int?
    public var schedDep: Double
    /// You've arrived (or the trip is over).
    public var arrived = false
    /// The change to your next train, from the connection check: `miss`, `broken`, `tight`, or anything else.
    public var connection: String?

    public init(canceled: Bool = false, boardCanceled: Bool = false, alightCanceled: Bool = false, partial: PartialRun? = nil, deviations: [String] = [], depDelayMin: Int? = nil, arrDelayMin: Int? = nil, schedDep: Double, arrived: Bool = false, connection: String? = nil) {
        self.canceled = canceled
        self.boardCanceled = boardCanceled
        self.alightCanceled = alightCanceled
        self.partial = partial
        self.deviations = deviations
        self.depDelayMin = depDelayMin
        self.arrDelayMin = arrDelayMin
        self.schedDep = schedDep
        self.arrived = arrived
        self.connection = connection
    }
}

public nonisolated enum Disruption {
    public static let significantDelayMin = 15
    private static let replacement = try? NSRegularExpression(
        pattern: "ersättningsbuss|buss(ar)? ersätter|ersätts med buss|replacement bus", options: .caseInsensitive
    )
    public static let severe: Set<DisruptionKind> = [.canceled, .startsLater, .endsEarly, .gap, .skipsBoard, .skipsAlight, .connectionMissed]

    private static func mentionsReplacementBus(_ text: String) -> Bool {
        let range = NSRange(text.startIndex..., in: text)
        return replacement?.firstMatch(in: text, range: range) != nil
    }

    public static func assess(_ input: DisruptionInput, now: Double) -> (kinds: [DisruptionKind], urgency: Urgency?) {
        var kinds: [DisruptionKind] = []
        let p = input.partial
        // A train the stops show running part of your way isn't wholly cancelled, whatever an older flag says.
        if p?.kind == .full || (input.canceled && p?.kind != .partial) {
            kinds.append(.canceled)
        } else {
            if let p, p.kind == .partial {
                if p.runsFrom != nil { kinds.append(p.startsThere ? .startsLater : .skipsBoard) }
                if p.runsTo != nil { kinds.append(p.endsThere ? .endsEarly : .skipsAlight) }
                if !p.gaps.isEmpty { kinds.append(.gap) }
            } else {
                if input.boardCanceled { kinds.append(.skipsBoard) }
                if input.alightCanceled { kinds.append(.skipsAlight) }
            }
            if input.deviations.contains(where: mentionsReplacementBus) { kinds.append(.replacement) }
            if max(input.depDelayMin ?? 0, input.arrDelayMin ?? 0) >= significantDelayMin { kinds.append(.delayed) }
        }
        if input.connection == "miss" || input.connection == "broken" {
            kinds.append(.connectionMissed)
        } else if input.connection == "tight" {
            kinds.append(.connectionAtRisk)
        }
        if kinds.isEmpty { return (kinds, nil) }
        if input.arrived { return (kinds, .info) }
        let soon = input.schedDep - now <= 3 * 3_600_000
        let days = input.schedDep - now <= 48 * 3_600_000
        let isSevere = kinds.contains(where: severe.contains)
        let urgency: Urgency = isSevere ? (soon ? .actNow : days ? .headsUp : .info) : (soon ? .headsUp : .info)
        return (kinds, urgency)
    }

    /// What you may be able to claim, as the rules are written (checked 2026-10-22):
    /// - Konsumentverket: train journeys of 15 mil (150 km) or more, and any journey to another EU country, fall under
    ///   the EU train regulation; shorter Swedish journeys under the law on public transport passengers' rights, which
    ///   gives a price reduction from 20 minutes late.
    /// - EU (Your Europe): arriving 60 to 119 minutes late, 25% of the ticket price; 120 or more, 50%; a cancellation
    ///   that would make you over 60 minutes late gives a refund or re-routing.
    /// Norway isn't covered here (no rules checked yet): the operator's own terms apply. Nor is a trip that stays in
    /// Finland: the EU train regulation (2021/782) is EU law, so it applies there too, but which Finnish services it
    /// covers and any national rules on top are not checked (unverified); the app points to the operator's own terms
    /// and never to the Swedish rule. A trip that crosses a border is EU either way. `canceled` is whether your journey on
    /// this train is cancelled: also when it runs only part of your way (it doesn't take you from where you get on, or
    /// to where you get off), which is a cancellation of the trip you bought.
    public enum Rights: Equatable, Sendable {
        public enum EUClaim: String, Sendable { case refundOrReroute = "refund_or_reroute", compensation25 = "compensation_25", compensation50 = "compensation_50" }
        case eu(EUClaim?)
        case seShort(priceReduction: Bool)
        case `operator`
    }

    /// The stop's `canceled` flag from its arrival and departure (nil: not known), by its role on the trip: where you
    /// get on, the departure; where you get off, the arrival; anywhere else, every one that is known.
    public static func stopCanceled(role: StopRole, arr: Bool?, dep: Bool?) -> Bool {
        if role == .board { return dep == true }
        if role == .alight { return arr == true }
        let known = [arr, dep].compactMap { $0 }
        return !known.isEmpty && known.allSatisfy { $0 }
    }

    /// How much of your part the train runs (`cancellationOf` in `packages/shared/src/disruption.ts`, the same rule the
    /// server runs): nil when it runs all of it, a stop it only skips on the way included. From the stops' arrival and
    /// departure cancellations where the server sends them, else their per-role `canceled` flag.
    public static func cancellation(of stops: [LegStop]) -> PartialRun? {
        let r = stops.filter { $0.role.isRidden }
        let n = r.count
        guard n >= 2 else { return nil }
        let arrOff = { (s: LegStop) in s.arrCanceled ?? s.canceled }
        let depOff = { (s: LegStop) in s.depCanceled ?? s.canceled }
        let leaves = { (i: Int) in i < n - 1 && !depOff(r[i]) }
        let reaches = { (i: Int) in i > 0 && !arrOff(r[i]) }
        guard let first = r.indices.first(where: leaves), let last = r.indices.last(where: reaches), first < last else {
            return PartialRun(kind: .full)
        }
        var gaps: [PartialRun.Gap] = []
        if first + 1 < last {
            for i in (first + 1)..<last where reaches(i) && !leaves(i) {
                if let k = r.indices.first(where: { $0 > i && $0 < last && leaves($0) }) {
                    gaps.append(.init(from: r[i].stationId, to: r[k].stationId, fromName: r[i].name, toName: r[k].name))
                }
            }
        }
        let runsFrom = first > 0 ? r[first] : nil
        let runsTo = last < n - 1 ? r[last] : nil
        if runsFrom == nil && runsTo == nil && gaps.isEmpty { return nil }
        let boardAt = stops.firstIndex(of: r[0])!
        let alightAt = stops.firstIndex(of: r[n - 1])!
        let before = boardAt > 0 ? stops[boardAt - 1] : nil
        let after = alightAt + 1 < stops.count ? stops[alightAt + 1] : nil
        return PartialRun(
            kind: .partial, runsFrom: runsFrom?.stationId, runsFromName: runsFrom?.name, runsTo: runsTo?.stationId, runsToName: runsTo?.name,
            // It starts there for you when nothing runs into it from your stop: its own arrival there is cancelled, the
            // stop before yours is cancelled too, or it arrives at yours and goes no further. It ends there when it doesn't
            // leave that stop, doesn't reach the one after yours, or leaves yours again. Else it may only skip your stop.
            startsThere: runsFrom != nil && (runsFrom?.arrCanceled == true || (before.map(depOff) ?? true) || r[0].arrCanceled == false),
            endsThere: runsTo != nil && (runsTo?.depCanceled == true || (after.map(arrOff) ?? true) || r[n - 1].depCanceled == false), gaps: gaps
        )
    }

    /// A trip's state: what its stops say, else what the server worked out (`Leg.cancellation`), else its flag alone.
    public static func cancellation(_ detail: LegDetail) -> PartialRun? {
        guard detail.stops.contains(where: { $0.role.isRidden }) else { return cancellation(detail.leg) }
        return cancellation(of: detail.stops) ?? (detail.leg.canceled ? PartialRun(kind: .full) : nil)
    }

    public static func cancellation(_ leg: Leg) -> PartialRun? {
        leg.cancellation ?? (leg.canceled ? PartialRun(kind: .full) : nil)
    }

    /// The train runs none of your part (a part-way one is not cancelled, whatever an older flag says).
    public static func fullyCanceled(_ leg: Leg, partial: PartialRun?) -> Bool {
        partial.map { $0.kind == .full } ?? leg.canceled
    }

    public static func passengerRights(countries: [String], journeyKm: Double, arrDelayMin: Int?, canceled: Bool) -> Rights {
        let international = Set(countries).count > 1
        if !international && (countries.allSatisfy({ $0 == "NO" }) || countries.allSatisfy({ $0 == "FI" }) || countries.allSatisfy({ $0 == "DK" })) { return .operator }
        let late = arrDelayMin ?? 0
        if international || journeyKm >= 150 {
            if canceled { return .eu(.refundOrReroute) }
            return .eu(late >= 120 ? .compensation50 : late >= 60 ? .compensation25 : nil)
        }
        return .seShort(priceReduction: canceled || late >= 20)
    }

    /// Your Europe's page on rail passenger rights, in each EU language the app has (Norwegian isn't one: English).
    public static let rightsLinkEU: [Language: String] = [
        .en: "https://europa.eu/youreurope/citizens/travel/passenger-rights/rail/index_en.htm",
        .sv: "https://europa.eu/youreurope/citizens/travel/passenger-rights/rail/index_sv.htm",
        .da: "https://europa.eu/youreurope/citizens/travel/passenger-rights/rail/index_da.htm",
        .fi: "https://europa.eu/youreurope/citizens/travel/passenger-rights/rail/index_fi.htm",
        .de: "https://europa.eu/youreurope/citizens/travel/passenger-rights/rail/index_de.htm",
        .pl: "https://europa.eu/youreurope/citizens/travel/passenger-rights/rail/index_pl.htm",
        .fr: "https://europa.eu/youreurope/citizens/travel/passenger-rights/rail/index_fr.htm",
    ]

    /// The rights page for `language`, else the English one.
    public static func rightsLinkEU(_ language: Language) -> String {
        rightsLinkEU[language] ?? rightsLinkEU[.en]!
    }
    public static let rightsLinkSweden = "https://www.konsumentverket.se/varor-och-tjanster-process/forsenat-eller-installt-tag/"

    // Why a train is late (reasons) lives in DelayCauses.swift, driven by data/delay_causes.json.
}

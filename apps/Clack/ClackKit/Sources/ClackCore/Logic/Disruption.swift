//
//  Disruption.swift
//  Clack
//

import Foundation

/// Disruptions on a saved trip (owner, 2026-10-22): what happened, what it does to the rest of the journey, how urgent
/// it is right now, and what you may be entitled to. Deterministic rules over the trip's own data; no guessing.
/// A port of `packages/shared/src/disruption.ts`. Times are epoch milliseconds.
public nonisolated enum DisruptionKind: String, Sendable, Hashable {
    /// The whole train is cancelled.
    case canceled
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

    public init(canceled: Bool = false, boardCanceled: Bool = false, alightCanceled: Bool = false, deviations: [String] = [], depDelayMin: Int? = nil, arrDelayMin: Int? = nil, schedDep: Double, arrived: Bool = false, connection: String? = nil) {
        self.canceled = canceled
        self.boardCanceled = boardCanceled
        self.alightCanceled = alightCanceled
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
    private static let severe: Set<DisruptionKind> = [.canceled, .skipsBoard, .skipsAlight, .connectionMissed]

    private static func mentionsReplacementBus(_ text: String) -> Bool {
        let range = NSRange(text.startIndex..., in: text)
        return replacement?.firstMatch(in: text, range: range) != nil
    }

    public static func assess(_ input: DisruptionInput, now: Double) -> (kinds: [DisruptionKind], urgency: Urgency?) {
        var kinds: [DisruptionKind] = []
        if input.canceled {
            kinds.append(.canceled)
        } else {
            if input.boardCanceled { kinds.append(.skipsBoard) }
            if input.alightCanceled { kinds.append(.skipsAlight) }
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
    /// and never to the Swedish rule. A trip that crosses a border is EU either way.
    public enum Rights: Equatable, Sendable {
        public enum EUClaim: String, Sendable { case refundOrReroute = "refund_or_reroute", compensation25 = "compensation_25", compensation50 = "compensation_50" }
        case eu(EUClaim?)
        case seShort(priceReduction: Bool)
        case `operator`
    }

    public static func passengerRights(countries: [String], journeyKm: Double, arrDelayMin: Int?, canceled: Bool) -> Rights {
        let international = Set(countries).count > 1
        if !international && (countries.allSatisfy({ $0 == "NO" }) || countries.allSatisfy({ $0 == "FI" })) { return .operator }
        let late = arrDelayMin ?? 0
        if international || journeyKm >= 150 {
            if canceled { return .eu(.refundOrReroute) }
            return .eu(late >= 120 ? .compensation50 : late >= 60 ? .compensation25 : nil)
        }
        return .seShort(priceReduction: canceled || late >= 20)
    }

    public static let rightsLinkEU: [Language: String] = [
        .en: "https://europa.eu/youreurope/citizens/travel/passenger-rights/rail/index_en.htm",
        .sv: "https://europa.eu/youreurope/citizens/travel/passenger-rights/rail/index_sv.htm",
    ]
    public static let rightsLinkSweden = "https://www.konsumentverket.se/varor-och-tjanster-process/forsenat-eller-installt-tag/"

    // Why a train is late (reasons) lives in DelayCauses.swift, driven by data/delay_causes.json.
}

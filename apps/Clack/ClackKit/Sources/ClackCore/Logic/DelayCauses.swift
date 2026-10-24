//
//  DelayCauses.swift
//  Clack
//

import Foundation

/// Why a train is late, in the app's language. `delay_causes.json` (copied from `data/` by
/// `scripts/ios/sync_assets.py`) maps Trafikverket's announcement codes and Digitraffic's cause codes to `cause.*`
/// keys in the locale files; Entur gives free text only. A cause the table doesn't know shows as its source wrote it,
/// never dropped. The server side is `packages/shared/src/delayCauses.ts`, reading the same file.
public nonisolated enum DelayCauses {
    /// `cause` says why a train is late; `notice` is a carriage, platform or service note.
    public enum Kind: String, Sendable, Hashable { case cause, notice }

    public struct Resolved: Equatable, Sendable {
        /// The locale key (`cause.signalFault`), or nil when only the source's own words are known.
        public let key: String?
        public let kind: Kind
        /// What to show without a key: the source's text (Digitraffic: the Finnish name).
        public let text: String?
    }

    struct Entry: Decodable, Sendable {
        let key: String?
        let kind: String?
        let sv: String?
        let fi: String?
    }

    public struct Table: Decodable, Sendable {
        let trv: [String: Entry]
        let trvText: [String: Entry]
        let dt: [String: Entry]

        /// Trafikverket's announced Swedish text (lower case) to its entry: the old exact-text lookup, from the table.
        let bySwedishText: [String: Entry]

        private enum CodingKeys: String, CodingKey { case trv, trvText, dt }

        init(trv: [String: Entry], trvText: [String: Entry], dt: [String: Entry]) {
            self.trv = trv
            self.trvText = trvText
            self.dt = dt
            var text: [String: Entry] = [:]
            for entry in trv.values { if let sv = entry.sv { text[sv.lowercased()] = entry } }
            bySwedishText = text
        }

        public init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            self.init(trv: try c.decode([String: Entry].self, forKey: .trv), trvText: try c.decode([String: Entry].self, forKey: .trvText), dt: try c.decode([String: Entry].self, forKey: .dt))
        }

        /// The table in a bundle (this package's resources unless told otherwise); empty when it can't be read.
        public static func load(bundle: Bundle = L10n.resources) -> Table {
            guard let url = bundle.url(forResource: "delay_causes", withExtension: "json"),
                  let data = try? Data(contentsOf: url),
                  let table = try? JSONDecoder().decode(Table.self, from: data) else {
                return Table(trv: [:], trvText: [:], dt: [:])
            }
            return table
        }
    }

    public static let table = Table.load()

    /// The codes above a Digitraffic code, most specific first: P109, P1, P.
    static func chain(_ code: String) -> [String] {
        let c = code.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        var out = [c]
        if c.count > 2 { out.append(String(c.prefix(2))) }
        if c.count > 1 { out.append(String(c.prefix(1))) }
        return out
    }

    /// Code first, then the exact text, then the raw words.
    public static func resolve(_ cause: LegStop.Cause, table: Table = DelayCauses.table) -> Resolved {
        let code = cause.code?.trimmingCharacters(in: .whitespacesAndNewlines)
        let raw = cause.text?.trimmingCharacters(in: .whitespacesAndNewlines)
        let text = (raw?.isEmpty ?? true) ? nil : raw
        switch cause.src {
        case "digitraffic":
            guard let code, !code.isEmpty else { return Resolved(key: nil, kind: .cause, text: text) }
            for c in chain(code) {
                if let key = table.dt[c]?.key { return Resolved(key: key, kind: .cause, text: nil) }
            }
            return Resolved(key: nil, kind: .cause, text: text ?? table.dt[code.uppercased()]?.fi)
        case "trv":
            let entry = code.flatMap { table.trv[$0.uppercased()] } ?? text.flatMap { table.bySwedishText[$0.lowercased()] ?? table.trvText[$0] }
            if let entry, let key = entry.key { return Resolved(key: key, kind: Kind(rawValue: entry.kind ?? "") ?? .cause, text: text) }
            return Resolved(key: nil, kind: .cause, text: text)
        default:
            return Resolved(key: nil, kind: .cause, text: text)
        }
    }

    /// The words to show: translated through `translate` (a locale key to its text) when the table knows the cause,
    /// else as the source wrote it. Nil when there is nothing to show.
    public static func text(_ cause: LegStop.Cause, table: Table = DelayCauses.table, translate: (String) -> String) -> String? {
        let r = resolve(cause, table: table)
        if let key = r.key { return translate(key) }
        return r.text
    }

    /// True for the platform-change notice (ANA055 "Spårändrat"), which the screens show as a platform change instead.
    public static func isPlatformChange(_ cause: LegStop.Cause, table: Table = DelayCauses.table) -> Bool {
        resolve(cause, table: table).key == "cause.platformChanged"
    }

    /// Lower case the first letter for use inside a sentence ("Signal fault" becomes "signal fault"); an acronym
    /// at the start stays as it is.
    static func lowerFirst(_ s: String) -> String {
        guard let first = s.first else { return s }
        let second = s.dropFirst().first
        if let second, second.isUppercase { return s }
        return first.lowercased() + s.dropFirst()
    }

    public struct Reason: Equatable, Sendable {
        public let text: String
        /// Who said so: Trafikverket, Fintraffic or Entur.
        public let source: String
    }

    /// The reasons among a train's causes (not the notices), as phrases for a sentence, in the order seen, without
    /// repeats. Only what the table knows counts: unknown Trafikverket texts may be notices, and Entur's free text and
    /// Finnish names don't read in the app's language.
    public static func reasons(_ causes: [LegStop.Cause], table: Table = DelayCauses.table, translate: (String) -> String) -> [Reason] {
        var seen = Set<String>()
        var out: [Reason] = []
        for cause in causes {
            let r = resolve(cause, table: table)
            guard r.kind == .cause, let key = r.key else { continue }
            let text = lowerFirst(translate(key))
            if seen.insert(text).inserted { out.append(Reason(text: text, source: sourceName(cause.src))) }
        }
        return out
    }

    public static func sourceName(_ src: String) -> String {
        switch src {
        case "digitraffic": "Fintraffic"
        case "entur": "Entur"
        default: "Trafikverket"
        }
    }
}

public extension L10n {
    /// A cause in the app's language: translated when known, else as its source wrote it; nil when empty.
    func cause(_ cause: LegStop.Cause) -> String? {
        DelayCauses.text(cause) { self.t($0) }
    }

    /// The causes as short notes for a stop or a board row: platform changes left out (shown as such), no repeats.
    func causeNotes(_ causes: [LegStop.Cause]) -> [String] {
        var out: [String] = []
        for c in causes where !DelayCauses.isPlatformChange(c) {
            if let text = cause(c), !out.contains(text) { out.append(text) }
        }
        return out
    }
}

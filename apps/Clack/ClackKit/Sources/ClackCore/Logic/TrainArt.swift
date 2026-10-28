//
//  TrainArt.swift
//  Clack
//

import Foundation

/// Which train drawing to show for a train type and operator (apps/web/src/components/trains/TrainPicture.tsx,
/// docs/TRAIN_ART.md): a detailed side view where one has been drawn for that model, in the operator's livery when
/// it's been drawn and unpainted when it hasn't; otherwise the nearest drawn model, unpainted and faded, as a
/// stand-in. Nothing is guessed: with no type, or a type that names two models, the stand-in is fainter still.
public nonisolated enum TrainArt {
    public struct Detailed: Sendable {
        /// The prefix of the asset names (`<model>-<livery>`).
        public let model: String
        /// Operators whose livery is drawn for this model; any other operator gets the unpainted version.
        public let liveries: [String]
        /// Operators whose trains of this type look different from the drawing: a stand-in.
        public var notFor: [String] = []
        /// Operators whose livery has its own id in the drawing (one operator, two schemes: the more common one).
        public var liveryOf: [String: String] = [:]

        public init(model: String, liveries: [String], notFor: [String] = [], liveryOf: [String: String] = [:]) {
            self.model = model
            self.liveries = liveries
            self.notFor = notFor
            self.liveryOf = liveryOf
        }
    }

    /// Keyed by train type id (data/train_types.json), not by art family: Flytoget shares the X3's simple outline.
    public static let detailed: [String: Detailed] = [
        "x3": Detailed(model: "x3", liveries: ["arlanda-express"]),
        // Two SJ schemes: unrebuilt X2 (grey) and rebuilt X2C (dark front). Nothing says which set runs which train:
        // the more common one.
        "x2000": Detailed(model: "x2000", liveries: ["sj"], liveryOf: ["sj": "sj-x2"]),
        "x40": Detailed(model: "x40", liveries: ["sj"]),
        "x55": Detailed(model: "x55", liveries: ["sj"]),
        "rc6_coaches": Detailed(model: "rc6_coaches", liveries: ["sj", "tagab"]),
        // SJ's night trains: the same Rc6, with couchette and sleeper coaches behind it. The drawing is the Rc6 whole
        // and the end of the first coach (a B7; SJ night trains also carry seated coaches, sj.se "Sittvagn 2 klass"),
        // so it is the right picture of the train's front (owner, 2026-10-27).
        "rc6_sleeper": Detailed(model: "rc6_coaches", liveries: ["sj"]),
        // Snälltåget's own locomotive and coaches (hand-made, owner-supplied).
        "snalltaget_coaches": Detailed(model: "snalltaget", liveries: ["snalltaget"]),
        "x60": Detailed(model: "x60", liveries: ["sl"]),
        // Västtåg's are mid-repaint (yellow to blue) and Östgötapendeln's cab-car paint differs between units.
        "x61": Detailed(model: "x61", liveries: ["pagatag", "ostgotapendeln"]),
        // Västtrafik's X61s: the X60's door layout, unpainted while the repaint is under way.
        // The yellow scheme (`x61vt-vasttagen-yellow`) is in the catalogue; the blue one is the current one.
        "x61_vt": Detailed(model: "x61vt", liveries: ["vasttagen"]),
        "x62": Detailed(model: "x62", liveries: ["norrtag"]),
        "x74": Detailed(model: "x74", liveries: ["vr"]),
        "y31": Detailed(model: "y31", liveries: ["krosatag", "vasttagen"]),
        "x31": Detailed(model: "x31", liveries: ["oresundstag", "dsb"]),
        "x11": Detailed(model: "x11", liveries: ["krosatag"]),
        "er1": Detailed(model: "er1", liveries: ["malartag", "tib"]),
        "flytoget71": Detailed(model: "flytoget71", liveries: ["flytoget"]),
        "flytoget78": Detailed(model: "flytoget78", liveries: ["flytoget"]),
        "regina": Detailed(model: "regina", liveries: ["vasttagen", "tib", "x-taget", "sj", "malartag", "varmlandstrafik", "norrtag"]),
        "no_flirt": Detailed(model: "no_flirt", liveries: ["vy"]),
        "no_type72": Detailed(model: "no_type72", liveries: ["go-ahead-norge", "vy"]),
        "no_type73": Detailed(model: "no_type73", liveries: ["sj-nord", "go-ahead-norge", "vy"]),
        "no_type69": Detailed(model: "no_type69", liveries: ["vy", "go-ahead-norge"]),
        "no_type93": Detailed(model: "no_type93", liveries: ["sj-nord"]),
        "no_el18": Detailed(model: "no_el18", liveries: ["vy"]),
        // Stockholm: SL's narrow-gauge lines (hand-made, owner-supplied drawings).
        "sl_x10p": Detailed(model: "x10p", liveries: ["sl"]),
        "sl_x15p": Detailed(model: "x15p", liveries: ["sl"]),
        "sl_c10": Detailed(model: "sl_c10", liveries: ["sl"]),
        "no_type76": Detailed(model: "no_type76", liveries: ["sj-nord"]),
        // Finland: hand-made, owner-supplied drawings (docs/TRAIN_ART.md). `vr-fi` is VR Group, Finland; the Swedish
        // `vr` (VR Snabbtåg, X74) never gets one of these. Sm2 also has a red scheme (`fi_sm2-vr-fi-red`) in the
        // catalogue; nothing says which unit wears which, so the green one is used. Sm5 is drawn in HSL's livery only.
        "fi_sm3": Detailed(model: "fi_sm3", liveries: ["vr-fi"]),
        "fi_sm2": Detailed(model: "fi_sm2", liveries: ["vr-fi"]),
        "fi_sm4": Detailed(model: "fi_sm4", liveries: ["vr-fi"]),
        // Every Sm5 is in HSL's purple whoever the timetable lists as operator: the units are owned by Pääkaupunkiseudun
        // Junakalusto, leased to HSL and operated by VR (en.wikipedia.org/wiki/VR_Class_Sm5, read 2026-10-25). Most Helsinki
        // commuter trips are listed under VR (`vr-fi`), so VR gets the HSL scheme too.
        "fi_sm5": Detailed(model: "fi_sm5", liveries: ["hsl", "vr-fi"], liveryOf: ["vr-fi": "hsl"]),
        "fi_sr2_ic": Detailed(model: "fi_sr2_ic", liveries: ["vr-fi"]),
        "fi_sr3_ic": Detailed(model: "fi_sr3_ic", liveries: ["vr-fi"]),
        "fi_dm12": Detailed(model: "fi_dm12", liveries: ["vr-fi"]),
        // Registered but no rule uses it: which coach type (Edo?) it shows is unverified.
        "fi_ic_cab": Detailed(model: "fi_ic_cab", liveries: ["vr-fi"]),
        // Registered, no rule uses it: which wagon types it shows is not recorded.
        "fi_ic_coaches": Detailed(model: "fi_ic_coaches", liveries: ["vr-fi"]),
        // Denmark (the owner's drawings, 2026-10-28; DENMARK_TRAINS.md). One livery per operator, as the data can't tell
        // repainted units apart: Vores Tog's Desiros keep Arriva's paint (no dated photo shows another), its LINTs the
        // teal. The other drawn schemes (`dk_ic3-dsb-silver`, `dk_ir4-dsb-grey`, `dk_stog_sa-dsb-old`,
        // `dk_lint41-gocollective`) are real but on a minority of units, so no operator gets them.
        "dk_ic3": Detailed(model: "dk_ic3", liveries: ["dsb"]),
        "dk_ir4": Detailed(model: "dk_ir4", liveries: ["dsb"]),
        "dk_ic2": Detailed(model: "dk_ic2", liveries: ["lokaltog"]),
        "dk_stog_sa": Detailed(model: "dk_stog_sa", liveries: ["dsb"]),
        "dk_eb_dd": Detailed(model: "dk_eb_dd", liveries: ["dsb"]),
        "dk_eb_talgo": Detailed(model: "dk_eb_talgo", liveries: ["dsb"]),
        "dk_lint41": Detailed(model: "dk_lint41", liveries: ["vores-tog", "lokaltog"]),
        "dk_lint41_nj": Detailed(model: "dk_lint41_nj", liveries: ["nt"], liveryOf: ["nt": "nordjyske"]),
        "dk_desiro": Detailed(model: "dk_desiro", liveries: ["vores-tog", "nt"], liveryOf: ["vores-tog": "arriva", "nt": "nordjyske"]),
        "dk_mireo_b": Detailed(model: "dk_mireo_b", liveries: ["midttrafik"], liveryOf: ["midttrafik": "midtjyske"]),
    ]

    /// The drawn model nearest to each family ("art" in data/train_types.json), shown unpainted and faded when the
    /// train's own model isn't drawn. Steam and night trains have no closer drawing than a locomotive with coaches.
    public static let standIn: [String: String] = [
        "x2000": "x2000", "x3": "x3", "coradia": "x60", "regina": "regina", "contessa": "x11", "flirt": "no_flirt",
        "double_deck": "x40", "railcar": "y31", "dk_railcar": "dk_lint41", "loco": "rc6_coaches", "loco_sleeper": "rc6_coaches", "steam": "rc6_coaches",
    ]
    /// No type at all: the most common kind of train here, a regional electric unit.
    public static let unknownStandIn = "x60"

    public static func hasDetailedArt(typeId: String?, operatorId: String?) -> Bool {
        guard let typeId, let d = detailed[typeId] else { return false }
        if let operatorId, d.notFor.contains(operatorId) { return false }
        return true
    }

    public struct Picture: Equatable, Sendable {
        /// The asset name, `<model>-<livery>`.
        public let asset: String
        /// The nearest drawn model, not this train's own.
        public let isStandIn: Bool
        /// The train's type isn't known (or names two models): fainter still.
        public let isUnknown: Bool

        public init(asset: String, isStandIn: Bool, isUnknown: Bool) {
            self.asset = asset
            self.isStandIn = isStandIn
            self.isUnknown = isUnknown
        }
    }

    /// The models an uncertain type names ("X11 or X14", "Itino (Y31/Y32) or Y2"), by train type id, each as the id its
    /// drawing goes by. Only the ones that have been drawn matter: if one of them is drawn in this operator's livery
    /// the picture shows it (owner's policy, 2026-10-23), and the type's name still says it is one of the two.
    public static let candidates: [String: [String]] = [
        "x11_x14": ["x11"],
        "itino_y2": ["y31"],
        "no_type69_72": ["no_type72", "no_type69"],
        // Roslagsbanan: X10p or X15p run side by side and nothing says which train is which; the X10p is simply listed first.
        "sl_roslagsbanan": ["sl_x10p", "sl_x15p"],
        "flytoget": ["flytoget71", "flytoget78"],
        // Finland: InterCity locomotive Sr2 or Sr3; Helsinki commuter Sm5, Sm4 or Sm2 (Digitraffic compositions,
        // 2026-10-24). The Sm5 is drawn in HSL's livery, which every Sm5 wears, so it comes first for VR and HSL alike; Sm5 is also the most common (739 of 1,047 commuter compositions on 2026-10-24).
        "fi_sr2_sr3": ["fi_sr2_ic", "fi_sr3_ic"],
        "fi_commuter": ["fi_sm5", "fi_sm4", "fi_sm2"],
        // Denmark: one drawing serves the S-tog SA and SE (same cab car); IC3 and IR4 are both red, so the IC3 is right
        // either way; NT's LINTs are the newer ones (17 of its 25 sets), Vores Tog's the first generation.
        "dk_stog": ["dk_stog_sa"],
        "dk_ic3_ir4": ["dk_ic3", "dk_ir4"],
        "dk_lint_desiro": ["dk_lint41_nj", "dk_lint41"],
        "dk_lint_ic2": ["dk_lint41", "dk_ic2"],
    ]

    /// The drawing of a candidate for an uncertain type, in the operator's own livery; nil when none has been drawn
    /// in it (the unpainted stand-in is used then, as before). The first candidate listed wins.
    public static func candidatePicture(typeId: String?, operatorId: String?) -> Picture? {
        guard let typeId, let operatorId, let options = candidates[typeId] else { return nil }
        for id in options {
            if let d = detailed[id], d.liveries.contains(operatorId), !d.notFor.contains(operatorId) {
                return Picture(asset: "\(d.model)-\(d.liveryOf[operatorId] ?? operatorId)", isStandIn: false, isUnknown: false)
            }
        }
        return nil
    }

    public static func picture(typeId: String?, art: String?, uncertain: Bool, operatorId: String?) -> Picture {
        if uncertain, let candidate = candidatePicture(typeId: typeId, operatorId: operatorId) { return candidate }
        if let typeId, !uncertain, let d = detailed[typeId], hasDetailedArt(typeId: typeId, operatorId: operatorId) {
            let livery = (operatorId.flatMap { id in d.liveries.contains(id) ? (d.liveryOf[id] ?? id) : nil }) ?? "plain"
            return Picture(asset: "\(d.model)-\(livery)", isStandIn: false, isUnknown: false)
        }
        let standInId = art.flatMap { standIn[$0] } ?? unknownStandIn
        let model = (detailed[standInId] ?? detailed[unknownStandIn]!).model
        return Picture(asset: "\(model)-plain", isStandIn: true, isUnknown: typeId == nil || uncertain)
    }
}

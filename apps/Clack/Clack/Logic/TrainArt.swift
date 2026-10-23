//
//  TrainArt.swift
//  Clack
//

import Foundation

/// Which train drawing to show for a train type and operator (apps/web/src/components/trains/TrainPicture.tsx,
/// docs/TRAIN_ART.md): a detailed side view where one has been drawn for that model, in the operator's livery when
/// it's been drawn and unpainted when it hasn't; otherwise the nearest drawn model, unpainted and faded, as a
/// stand-in. Nothing is guessed: with no type, or a type that names two models, the stand-in is fainter still.
nonisolated enum TrainArt {
    struct Detailed: Sendable {
        /// The prefix of the asset names (`<model>-<livery>`).
        let model: String
        /// Operators whose livery is drawn for this model; any other operator gets the unpainted version.
        let liveries: [String]
        /// Operators whose trains of this type look different from the drawing: a stand-in.
        var notFor: [String] = []
        /// Operators whose livery has its own id in the drawing (one operator, two schemes: the more common one).
        var liveryOf: [String: String] = [:]
    }

    /// Keyed by train type id (data/train_types.json), not by art family: Flytoget shares the X3's simple outline.
    static let detailed: [String: Detailed] = [
        "x3": Detailed(model: "x3", liveries: ["arlanda-express"]),
        // Two SJ schemes: unrebuilt X2 (grey) and rebuilt X2C (dark front). Nothing says which set runs which train:
        // the more common one.
        "x2000": Detailed(model: "x2000", liveries: ["sj"], liveryOf: ["sj": "sj-x2"]),
        "x40": Detailed(model: "x40", liveries: ["sj"]),
        "x55": Detailed(model: "x55", liveries: ["sj"]),
        "rc6_coaches": Detailed(model: "rc6_coaches", liveries: ["sj"]),
        "x60": Detailed(model: "x60", liveries: ["sl"]),
        // Västtåg's are mid-repaint (yellow to blue) and Östgötapendeln's cab-car paint differs between units.
        "x61": Detailed(model: "x61", liveries: ["pagatag"]),
        // Västtrafik's X61s: the X60's door layout, unpainted while the repaint is under way.
        "x61_vt": Detailed(model: "x61vt", liveries: []),
        "x62": Detailed(model: "x62", liveries: ["norrtag"]),
        "x74": Detailed(model: "x74", liveries: ["vr"]),
        "y31": Detailed(model: "y31", liveries: ["krosatag", "vasttagen"]),
        "x31": Detailed(model: "x31", liveries: ["oresundstag", "dsb"]),
        "x11": Detailed(model: "x11", liveries: ["krosatag"]),
        "er1": Detailed(model: "er1", liveries: ["malartag"]),
        "flytoget71": Detailed(model: "flytoget71", liveries: ["flytoget"]),
        "flytoget78": Detailed(model: "flytoget78", liveries: ["flytoget"]),
        "regina": Detailed(model: "regina", liveries: ["vasttagen", "tib", "x-taget", "sj", "malartag"]),
        "no_flirt": Detailed(model: "no_flirt", liveries: ["vy"]),
        "no_type72": Detailed(model: "no_type72", liveries: ["go-ahead-norge", "vy"]),
        "no_type73": Detailed(model: "no_type73", liveries: ["sj-nord", "go-ahead-norge"]),
        "no_type76": Detailed(model: "no_type76", liveries: ["sj-nord"]),
    ]

    /// The drawn model nearest to each family ("art" in data/train_types.json), shown unpainted and faded when the
    /// train's own model isn't drawn. Steam and night trains have no closer drawing than a locomotive with coaches.
    static let standIn: [String: String] = [
        "x2000": "x2000", "x3": "x3", "coradia": "x60", "regina": "regina", "contessa": "x11", "flirt": "no_flirt",
        "double_deck": "x40", "railcar": "y31", "loco": "rc6_coaches", "loco_sleeper": "rc6_coaches", "steam": "rc6_coaches",
    ]
    /// No type at all: the most common kind of train here, a regional electric unit.
    static let unknownStandIn = "x60"

    static func hasDetailedArt(typeId: String?, operatorId: String?) -> Bool {
        guard let typeId, let d = detailed[typeId] else { return false }
        if let operatorId, d.notFor.contains(operatorId) { return false }
        return true
    }

    struct Picture: Equatable, Sendable {
        /// The asset name, `<model>-<livery>`.
        let asset: String
        /// The nearest drawn model, not this train's own.
        let isStandIn: Bool
        /// The train's type isn't known (or names two models): fainter still.
        let isUnknown: Bool
    }

    static func picture(typeId: String?, art: String?, uncertain: Bool, operatorId: String?) -> Picture {
        if let typeId, !uncertain, let d = detailed[typeId], hasDetailedArt(typeId: typeId, operatorId: operatorId) {
            let livery = (operatorId.flatMap { id in d.liveries.contains(id) ? (d.liveryOf[id] ?? id) : nil }) ?? "plain"
            return Picture(asset: "\(d.model)-\(livery)", isStandIn: false, isUnknown: false)
        }
        let standInId = art.flatMap { standIn[$0] } ?? unknownStandIn
        let model = (detailed[standInId] ?? detailed[unknownStandIn]!).model
        return Picture(asset: "\(model)-plain", isStandIn: true, isUnknown: typeId == nil || uncertain)
    }
}

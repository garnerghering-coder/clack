//
//  Onboard.swift
//  Clack
//

import Foundation

/// What a train type typically has on board at one operator, from the operator's own pages with a source and the date
/// someone checked it (a port of `typicalAmenities` in `packages/shared/src/onboard.ts`). Shown as "Typically", never
/// as a promise.
nonisolated enum Onboard {
    /// The amenity keys, in the order the app lists them.
    static let amenityKeys = [
        "catering", "wifi", "power", "quiet_car", "first_class", "family_area", "pets_area", "bikes",
        "wheelchair_space", "step_free", "accessible_toilet", "sleeper",
    ]

    /// Claims older than this are hidden until someone checks the operator's page again.
    static let claimMaxAgeDays: Double = 365

    /// The typical amenities of a train type at an operator: claims for the operator as a whole, overridden by claims
    /// for that type. Stale claims are left out; an unknown operator gets nothing (nothing is guessed).
    static func typicalAmenities(
        _ table: [AmenityEntry], operatorId: String?, typeId: String?, now: Double
    ) -> [String: AmenityClaim] {
        guard let operatorId else { return [:] }
        var out: [String: AmenityClaim] = [:]
        func fresh(_ claim: AmenityClaim) -> Bool {
            guard let verified = Format.isoToMidnightMs(claim.verified) else { return false }
            return now - verified <= claimMaxAgeDays * 86_400_000
        }
        let layers =
            table.filter { $0.match.operator == operatorId && $0.match.type == nil }
            + table.filter { $0.match.operator == operatorId && $0.match.type != nil && $0.match.type == typeId }
        for entry in layers {
            for (key, claim) in entry.claims where fresh(claim) { out[key] = claim }
        }
        return out
    }
}

//
//  Delay.swift
//  Clack
//

import Foundation

/// Delay colour bands (DESIGN §2.1) and the on-time threshold (SPEC §14); a port of `packages/shared/src/delay.ts`.
nonisolated enum DelayBand: String, Sendable {
    case onTime = "on_time"
    case slight
    case late
    case veryLate = "very_late"
    case cancelled
    case unknown

    /// Band for a delay in whole minutes (negative = early).
    init(delayMin: Int?, canceled: Bool = false) {
        if canceled {
            self = .cancelled
        } else if let delayMin {
            switch delayMin {
            case ...0: self = .onTime
            case 1...15: self = .slight
            case 16...30: self = .late
            default: self = .veryLate
            }
        } else {
            self = .unknown
        }
    }
}

nonisolated enum Delay {
    /// On time means at most this many minutes late.
    static let onTimeMaxDelayMin = 5

    /// Delay = actual − advertised, in whole minutes (SPEC §10). Both are minute-precision times.
    static func minutes(advertised: Double?, actual: Double?) -> Int? {
        guard let advertised, let actual else { return nil }
        let a = (actual / 60_000).rounded(.down) * 60_000
        let b = (advertised / 60_000).rounded(.down) * 60_000
        return Int(((a - b) / 60_000).rounded())
    }

    static func isOnTime(_ delayMin: Int?) -> Bool {
        guard let delayMin else { return false }
        return delayMin <= onTimeMaxDelayMin
    }
}

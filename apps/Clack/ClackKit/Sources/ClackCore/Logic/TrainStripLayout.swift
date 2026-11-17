//
//  TrainStripLayout.swift
//  Clack
//

import Foundation

/// How a search result's trains are laid out side by side (owner, 2026-11-17). Every drawing is to the same scale
/// (1 m = 40 drawing units, docs/TRAIN_ART.md), so all are shown at one scale on one rail line: a double-decker stays
/// taller than a locomotive. Each train gets a share of the row's width, the first (the one you board) the most; a
/// train that fits its share is shown whole, a longer one is cut from the back so its nose stays. Each later train
/// slides a little under the one before it, which is in front.
public nonisolated enum TrainStripLayout {
    /// Points per drawing unit: about 5.2 pt per metre. Most cab cars come out 100–125 pt long.
    public static let scale: Double = 0.13
    /// The tallest drawing's canvas (the Finnish double-deckers, 220 units): the row's height.
    public static let tallestCanvas: Double = 220
    public static var height: Double { tallestCanvas * scale }
    /// How far a train's rear slides under the nose in front, at most.
    public static let overlap: Double = 12
    /// The least of a later train that shows: its nose and cab.
    public static let minShown: Double = 40

    public nonisolated struct Slot: Equatable, Sendable {
        /// The drawing's width as shown (the part under the train in front included).
        public let width: Double
        /// Cut from the back: the drawing is longer than its share.
        public let cut: Bool
        /// How far it slides under the train before it (0 for the first).
        public let overlap: Double

        public init(width: Double, cut: Bool, overlap: Double) {
            self.width = width
            self.cut = cut
            self.overlap = overlap
        }
    }

    /// Each train's share of `width` that shows: all of it for one train; half each for two; 38, 31, 31% for three;
    /// for four or more 31% for the first and the rest shared, never under `minShown`.
    public static func caps(count: Int, width: Double) -> [Double] {
        switch count {
        case ..<1: return []
        case 1: return [width]
        case 2: return [width * 0.5, width * 0.5]
        case 3: return [width * 0.38, width * 0.31, width * 0.31]
        default:
            let rest = max(minShown, width * 0.69 / Double(count - 1))
            return [width * 0.31] + Array(repeating: rest, count: count - 1)
        }
    }

    /// The slots for drawings `naturals` points long (at `scale`) in a row `width` wide.
    public static func slots(naturals: [Double], width: Double) -> [Slot] {
        let caps = caps(count: naturals.count, width: width)
        return naturals.enumerated().map { i, natural in
            guard i > 0 else { return Slot(width: min(natural, caps[0]), cut: natural > caps[0], overlap: 0) }
            // The part under the train in front doesn't count against the share: what shows stays within it.
            let under = min(overlap, 0.2 * min(natural, caps[i]))
            let shown = min(natural, caps[i] + under)
            return Slot(width: shown, cut: natural > shown, overlap: under)
        }
    }
}

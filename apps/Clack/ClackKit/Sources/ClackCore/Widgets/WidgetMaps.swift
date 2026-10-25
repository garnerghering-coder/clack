//
//  WidgetMaps.swift
//  ClackCore
//

import CoreGraphics
import Foundation

/// The real map behind the Year in rail widget's routes: the app draws it (a widget can't run MapLibre) and leaves the
/// pictures in the App Group, one for the dark look and one for the light, named after the routes they show. A widget whose
/// routes have no picture (yet) draws the lines alone.
public nonisolated enum WidgetMaps {
    /// What the app draws, in points (it is drawn at twice this): about the box the widget gives the map.
    public static let size = CGSize(width: 340, height: 200)

    /// Names the routes: the same routes always give the same key, any change gives another one.
    public static func key(_ year: WidgetSnapshot.YearBits) -> String {
        // FNV-1a over the points to three decimals (about 100 m); `Hasher` is different on every launch, so it can't be used.
        var hash: UInt64 = 0xcbf2_9ce4_8422_2325
        func mix(_ v: Int) {
            for shift in stride(from: 0, to: 64, by: 8) {
                hash ^= UInt64(truncatingIfNeeded: v >> shift) & 0xff
                hash = hash &* 0x0000_0100_0000_01b3
            }
        }
        mix(year.year)
        for route in year.routes {
            mix(route.count)
            for point in route where point.count == 2 {
                mix(Int((point[0] * 1000).rounded()))
                mix(Int((point[1] * 1000).rounded()))
            }
        }
        return String(hash, radix: 16)
    }

    public static func fileName(key: String, dark: Bool) -> String { "year-map-\(key)-\(dark ? "dark" : "light").png" }

    public static func url(key: String, dark: Bool) -> URL? {
        WidgetSnapshot.containerURL?.appendingPathComponent(fileName(key: key, dark: dark))
    }

    /// The pictures of other routes go.
    public static func prune(keeping key: String) {
        guard let dir = WidgetSnapshot.containerURL,
              let files = try? FileManager.default.contentsOfDirectory(atPath: dir.path) else { return }
        let keep = Set([fileName(key: key, dark: true), fileName(key: key, dark: false)])
        for name in files where name.hasPrefix("year-map-") && !keep.contains(name) {
            try? FileManager.default.removeItem(at: dir.appendingPathComponent(name))
        }
    }
}

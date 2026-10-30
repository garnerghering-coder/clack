import Foundation
import Testing
@testable import ClackCore

struct PlatformSectorsTests {
    @Test func jonkopingPlatformTwoHasSectorsAAndBWithADividerAcrossIt() throws {
        let url = URL(fileURLWithPath: #filePath).deletingLastPathComponent().appendingPathComponent("../../../../../data/stations/740000090.json").standardized
        let map = try JSONDecoder().decode(StationMap.self, from: Data(contentsOf: url))
        let p2 = try #require(map.platforms.first { $0.ref == "2" })
        let (sectors, dividers) = PlatformSectors.of(p2)
        #expect(sectors.map(\.sector) == ["2a", "2b"])
        // One divider, where OSM's two pieces of the platform meet (x ≈ −78 m), as wide as the platform (≈ 4.5 m).
        let d = try #require(dividers.first)
        #expect(dividers.count == 1)
        #expect(abs((d.0.x + d.1.x) / 2 + 78) < 3)
        #expect(abs(hypot(d.0.x - d.1.x, d.0.y - d.1.y) - 4.5) < 1)
        // Platform 1 has no sectors.
        let p1 = try #require(map.platforms.first { $0.ref == "1" })
        #expect(PlatformSectors.of(p1).sectors.isEmpty)
    }

    @Test func sectorsGetTheirOwnChipsOnlyWhenZoomedIn() throws {
        let url = URL(fileURLWithPath: #filePath).deletingLastPathComponent().appendingPathComponent("../../../../../data/stations/740000090.json").standardized
        let map = try JSONDecoder().decode(StationMap.self, from: Data(contentsOf: url))
        let level = try #require(map.platforms.first { $0.ref == "2" }).level
        let far = StationSceneLogic.platformChips(map: map, level: level, marks: [], k: 0.1).map(\.label)
        let close = StationSceneLogic.platformChips(map: map, level: level, marks: [], k: 2).map(\.label)
        #expect(!far.contains("2a"))
        #expect(close.contains("2a") && close.contains("2b") && !close.contains("2"))
    }
}

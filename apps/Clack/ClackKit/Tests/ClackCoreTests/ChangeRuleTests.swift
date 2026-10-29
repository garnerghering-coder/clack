import ClackCore
import Testing

/// The same cases as apps/server/test/changes.test.ts: the app and the server must give the same verdict.
struct ChangeRuleTests {
    @Test func takesTheLargerOfTierAndCrossBorderNeverTheSum() {
        #expect(ChangeRule.minimum(tier: "default", from: "SE", to: "SE") == 7)
        #expect(ChangeRule.minimum(tier: "mid", from: "SE", to: "SE") == 10)
        #expect(ChangeRule.minimum(tier: "hub", from: "DK", to: "SE") == 15)
        #expect(ChangeRule.minimum(tier: "default", from: "DK", to: "SE") == 10)
        #expect(ChangeRule.minimum(tier: "default", from: "NO", to: "SE") == 15)
        #expect(ChangeRule.minimum(tier: "mid", from: "FI", to: "SE") == 15)
        #expect(ChangeRule.crossBorderMinimum(nil, "SE") == 0)
    }

    /// The same cases as packages/shared/src/changes.test.ts.
    @Test func takesTheUsualLatenessOffTheGapOnlyWithAWeekOfRecord() {
        #expect(ChangeRule.typicalLateMin(days: 6, p80Min: 12) == nil)
        #expect(ChangeRule.typicalLateMin(days: 7, p80Min: 12) == 12)
        #expect(ChangeRule.typicalLateMin(days: 28, p80Min: 7.6) == 8)
        #expect(ChangeRule.comfort(gapMin: 25, minMin: 15) == .normal)
        #expect(ChangeRule.comfort(gapMin: 25, minMin: 15, typicalLateMin: 3) == .tight)
        #expect(ChangeRule.comfort(gapMin: 25, minMin: 15, typicalLateMin: 11) == .risky)
        #expect(ChangeRule.comfort(gapMin: 25, minMin: 15, typicalLateMin: nil) == .normal)
        #expect(ChangeRule.comfort(gapMin: 40, minMin: 10, typicalLateMin: 0) == .relaxed)
    }

    @Test func ratesComfortAgainstTheMinimum() {
        #expect([6, 7, 10, 11, 14, 15].map { ChangeRule.comfort(gapMin: $0, minMin: 7) } == [.risky, .tight, .tight, .normal, .normal, .relaxed])
        #expect([14, 15, 22, 23, 30, 31].map { ChangeRule.comfort(gapMin: $0, minMin: 15) } == [.risky, .tight, .tight, .normal, .normal, .relaxed])
    }
}

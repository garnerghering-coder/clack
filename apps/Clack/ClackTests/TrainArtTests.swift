//
//  TrainArtTests.swift
//  ClackTests
//

import Testing
import UIKit
@testable import Clack
@testable import ClackCore

struct TrainArtTests {
    private func picture(_ type: String?, _ art: String? = nil, uncertain: Bool = false, _ op: String? = nil) -> TrainArt.Picture {
        TrainArt.picture(typeId: type, art: art, uncertain: uncertain, operatorId: op)
    }

    @Test func aDrawnModelInItsOperatorsLiveryIfThatLiveryIsDrawn() {
        #expect(picture("x40", "double_deck", "sj") == .init(asset: "x40-sj", isStandIn: false, isUnknown: false))
        #expect(picture("x2000", "x2000", "sj").asset == "x2000-sj-x2")
    }

    @Test func aDrawnModelWhoseOperatorsLiveryIsNotDrawnIsUnpainted() {
        #expect(picture("x40", "double_deck", "mtr").asset == "x40-plain")
        #expect(picture("x40", "double_deck", nil).asset == "x40-plain")
        #expect(picture("x61_vt", "coradia", "vt").asset == "x61vt-plain")
    }

    @Test func aModelThatIsNotDrawnGetsTheNearestDrawnOneUnpaintedAndFaded() {
        let p = picture("x31x", "contessa", "oresundstag")
        #expect(p == .init(asset: "x11-plain", isStandIn: true, isUnknown: false))
        #expect(picture("steamer", "steam").asset == "rc6_coaches-plain")
    }

    @Test func anUncertainTypeOrNoTypeAtAllIsTheFaintestStandIn() {
        let uncertain = picture("x40", "double_deck", uncertain: true, "sj")
        #expect(uncertain.isStandIn)
        #expect(uncertain.isUnknown)
        #expect(uncertain.asset == "x40-plain")
        #expect(picture(nil) == .init(asset: "x60-plain", isStandIn: true, isUnknown: true))
    }

    /// Owner's policy (2026-10-23): when a type names two or three models and one of them is drawn in this operator's
    /// livery, the picture shows it (the type's name still says "X11 or X14").
    @Test func anUncertainTypeShowsTheDrawnCandidateInTheOperatorsLivery() {
        #expect(picture("x11_x14", "contessa", uncertain: true, "krosatag") == .init(asset: "x11-krosatag", isStandIn: false, isUnknown: false))
        #expect(picture("itino_y2", "railcar", uncertain: true, "krosatag").asset == "y31-krosatag")
        #expect(picture("no_type69_72", "contessa", uncertain: true, "vy").asset == "no_type72-vy")
        #expect(picture("flytoget", "x3", uncertain: true, "flytoget").asset == "flytoget71-flytoget")
    }

    @Test func anUncertainTypeWithNoDrawnCandidateInThatLiveryStaysTheFaintStandIn() {
        #expect(picture("x11_x14", "contessa", uncertain: true, "vasttagen").isUnknown)
        #expect(picture("x11_x14", "contessa", uncertain: true, nil).isStandIn)
    }

    @Test func finnishTrainsGetTheirDrawingInVRsLivery() {
        #expect(picture("fi_sm3", "x2000", "vr-fi") == .init(asset: "fi_sm3-vr-fi", isStandIn: false, isUnknown: false))
        #expect(picture("fi_sr3_ic", "loco", "vr-fi").asset == "fi_sr3_ic-vr-fi")
        #expect(picture("fi_dm12", "railcar", "vr-fi").asset == "fi_dm12-vr-fi")
        // The Sm5 is drawn in HSL's livery only; VR's own gets the unpainted drawing.
        #expect(picture("fi_sm5", "flirt", "hsl").asset == "fi_sm5-hsl")
        #expect(picture("fi_sm5", "flirt", "vr-fi").asset == "fi_sm5-plain")
        #expect(picture("fi_sm4", "coradia", "hsl").asset == "fi_sm4-plain")
    }

    @Test func aFinnishTypeForAnOperatorWithoutALiveryIsUnpainted() {
        #expect(picture("fi_sm3", "x2000", nil).asset == "fi_sm3-plain")
        #expect(picture("fi_sm3", "x2000", "sj").asset == "fi_sm3-plain")
        #expect(picture("fi_sm3", "x2000", "nobody").asset == "fi_sm3-plain")
    }

    @Test func theSwedishVRIsNeverGivenAFinnishDrawing() {
        for (typeId, d) in TrainArt.detailed where d.model.hasPrefix("fi_") {
            #expect(!d.liveries.contains("vr"), "\(typeId)")
            #expect(picture(typeId, nil, "vr").asset == "\(d.model)-plain", "\(typeId)")
        }
        #expect(picture("x74", "flirt", "vr").asset == "x74-vr")
        #expect(picture("fi_commuter", "flirt", uncertain: true, "vr").isStandIn)
    }

    @Test func anUncertainFinnishTypeShowsTheCandidateDrawnInTheOperatorsLivery() {
        #expect(picture("fi_commuter", "flirt", uncertain: true, "hsl").asset == "fi_sm5-hsl")
        #expect(picture("fi_commuter", "flirt", uncertain: true, "vr-fi").asset == "fi_sm4-vr-fi")
        #expect(picture("fi_sr2_sr3", "loco", uncertain: true, "vr-fi").asset == "fi_sr2_ic-vr-fi")
    }

    @Test func theRedSm2SchemeIsInTheCatalogue() {
        #expect(UIImage(named: "fi_sm2-vr-fi-red") != nil)
    }

    @Test func slsNarrowGaugeLinesGetTheirOwnDrawingsInSLsLivery() {
        #expect(picture("sl_c10", nil, "sl").asset == "sl_c10-sl")
        #expect(picture("sl_x15p", nil, "sl").asset == "x15p-sl")
        // Roslagsbanan runs X10p and X15p and nothing says which: the first candidate drawn in SL's livery.
        #expect(picture("sl_roslagsbanan", nil, uncertain: true, "sl").asset == "x10p-sl")
        #expect(picture("x60", nil, "sl").asset == "x60-sl")
    }

    @Test func theNewLiveriesAreFoundForTheirOperators() {
        #expect(picture("x61", nil, "ostgotapendeln").asset == "x61-ostgotapendeln")
        #expect(picture("x61_vt", nil, "vasttagen").asset == "x61vt-vasttagen")
        #expect(picture("regina", nil, "varmlandstrafik").asset == "regina-varmlandstrafik")
        #expect(picture("no_type73", nil, "vy").asset == "no_type73-vy")
        #expect(picture("no_type69", nil, "vy").asset == "no_type69-vy")
        #expect(picture("no_el18", nil, "vy").asset == "no_el18-vy")
    }

    @Test func everyDrawingTheTableNamesIsInTheAssetCatalogue() {
        for (typeId, d) in TrainArt.detailed {
            #expect(UIImage(named: "\(d.model)-plain") != nil, "\(typeId): plain")
            for operatorId in d.liveries {
                let livery = d.liveryOf[operatorId] ?? operatorId
                #expect(UIImage(named: "\(d.model)-\(livery)") != nil, "\(typeId): \(livery)")
            }
        }
        for model in TrainArt.standIn.values {
            #expect(TrainArt.detailed[model] != nil, "\(model)")
        }
    }
}

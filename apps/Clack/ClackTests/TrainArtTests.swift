//
//  TrainArtTests.swift
//  ClackTests
//

import Testing
import UIKit
@testable import Clack

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

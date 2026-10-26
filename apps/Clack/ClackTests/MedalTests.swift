//
//  MedalTests.swift
//  ClackTests
//

import Foundation
import SwiftUI
import Testing
import UIKit
@testable import Clack
@testable import ClackCore

struct MedalTests {
    private func rgb(_ hex: String) -> [Double] {
        let value = UInt64(hex.dropFirst(), radix: 16) ?? 0
        return [Double((value >> 16) & 0xff), Double((value >> 8) & 0xff), Double(value & 0xff)].map { $0 / 255 }
    }

    private func luminance(_ c: [Double]) -> Double {
        let l = c.map { $0 <= 0.03928 ? $0 / 12.92 : pow(($0 + 0.055) / 1.055, 2.4) }
        return 0.2126 * l[0] + 0.7152 * l[1] + 0.0722 * l[2]
    }

    private func contrast(_ a: [Double], _ b: [Double]) -> Double {
        let (hi, lo) = (max(luminance(a), luminance(b)), min(luminance(a), luminance(b)))
        return (hi + 0.05) / (lo + 0.05)
    }

    /// The number sits about half way along the face's gradient; its ink must read there (WCAG 4.5:1).
    @Test func theInkReadsOnEveryFace() {
        for family in MilestoneFamily.knownCases {
            let (light, dark) = MedalStyle.face(family)
            let mid = zip(rgb(light), rgb(dark)).map { ($0 + $1) / 2 }
            let ink = UIColor(MedalStyle.ink(family)).cgColor.components?.prefix(3).map(Double.init) ?? []
            #expect(ink.count == 3)
            #expect(contrast(ink, mid) >= 4.5, "\(family.rawValue) ink is too faint on its face")
        }
    }

    @Test func everyKnownFamilyHasItsOwnFaceAndAnIcon() {
        let faces = MilestoneFamily.knownCases.map { MedalStyle.face($0).1 }
        #expect(Set(faces).count == faces.count)
        for family in MilestoneFamily.knownCases { #expect(!MedalStyle.icon(family, target: 1).isEmpty) }
        // A family from a newer server still draws, plain.
        #expect(MedalStyle.face(.unknown("future")).1 == "#8e8e8e")
    }

    @Test func oneOffMedalsShowAnIconNotANumber() {
        func medal(_ f: MilestoneFamily, _ t: Double) -> Milestone { Milestone(family: f, target: t, at: nil, legId: nil, value: nil) }
        #expect(MedalStyle.centre(medal(.kindsOfTrain, 5)) == nil)
        #expect(MedalStyle.centre(medal(.europeLength, 1)) == nil)
        #expect(MedalStyle.centre(medal(.borderCrossings, 5)) == "5")
        #expect(MedalStyle.centre(medal(.longestTrainKm, 1000)) == "1k")
    }

    @Test func theHomeCountryComesFromThePhonesRegion() {
        #expect(AppModel.homeCountry(forRegion: "NO") == .no)
        #expect(AppModel.homeCountry(forRegion: "FI") == .fi)
        #expect(AppModel.homeCountry(forRegion: "SE") == .se)
        #expect(AppModel.homeCountry(forRegion: "US") == nil)
        #expect(AppModel.homeCountry(forRegion: nil) == nil)
    }
}

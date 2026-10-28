//
//  DelayCausesTests.swift
//  ClackTests
//

import Foundation
import Testing
@testable import ClackCore

@MainActor
struct DelayCausesTests {
    let en = L10n(language: .en)
    let sv = L10n(language: .sv)
    func trv(_ code: String?, _ text: String?) -> LegStop.Cause { LegStop.Cause(src: "trv", code: code, text: text) }

    @Test func translatesTrafikverketCausesByCodeThenText() {
        #expect(en.cause(trv("ANA015", "Elfel")) == "Power fault")
        #expect(sv.cause(trv("ANA015", "Elfel")) == "Elfel")
        #expect(en.cause(trv(nil, "Signalfel")) == "Signal fault")
        #expect(en.cause(trv("ANA030", "Inväntat tåg")) == "Waiting for another train")
        #expect(sv.cause(trv("ANA064", "Tågmöte")) == "Tågmöte")
        #expect(en.cause(trv(nil, "Dörr 2-13")) == "Doors 2-13")
    }

    @Test func showsWhatItDoesNotKnowAsWritten() {
        #expect(en.cause(trv("ANA777", "Något nytt")) == "Något nytt")
        #expect(en.cause(LegStop.Cause(src: "entur", text: "Signal failure")) == "Signal failure")
        #expect(en.cause(LegStop.Cause(src: "digitraffic", code: "ZZ9")) == nil)
    }

    @Test func walksUpDigitrafficCodes() {
        #expect(en.cause(LegStop.Cause(src: "digitraffic", code: "P109")) == "Points failure")
        #expect(sv.cause(LegStop.Cause(src: "digitraffic", code: "P105")) == "Anläggningsfel")
        #expect(en.cause(LegStop.Cause(src: "digitraffic", code: "X")) == "Rataliikennekeskukselle ilmoitettavat syyt")
    }

    @Test func everyKeyInTheTableExistsInBothLanguages() {
        let table = DelayCauses.table
        let keys = Set((Array(table.trv.values) + Array(table.trvText.values) + Array(table.dt.values)).compactMap(\.key))
        #expect(keys.count > 100)
        for key in keys {
            #expect(en.t(key) != key, "en \(key)")
            #expect(sv.t(key) != key, "sv \(key)")
        }
    }

    @Test func leavesPlatformChangesAndNoticesOutOfNotesAndReasons() {
        let causes = [trv("ANA055", "Spårändrat"), trv("ANA050", "Signalfel"), trv("ANA031", "Kort tåg"), trv("ANA050", "Signalfel"), trv(nil, "Hpl C")]
        #expect(en.causeNotes(causes) == ["Signal fault", "Short train", "Hpl C"])
        #expect(sv.causeNotes(causes) == ["Signalfel", "Kort tåg", "Hpl C"])
        let reasons = DelayCauses.reasons(causes) { en.t($0) }
        #expect(reasons == [DelayCauses.Reason(text: "signal fault", source: "Trafikverket")])
        #expect(DelayCauses.reasons([trv(nil, "Tågkö")]) { sv.t($0) }.map(\.text) == ["tågkö"])
        #expect(DelayCauses.reasons([LegStop.Cause(src: "digitraffic", code: "P109")]) { en.t($0) } == [DelayCauses.Reason(text: "points failure", source: "Fintraffic")])
        #expect(DelayCauses.reasons([LegStop.Cause(src: "entur", text: "Delay")]) { en.t($0) }.isEmpty)
    }

    @Test func fallsBackToPlainTextsFromOlderServers() throws {
        let json = #"{"seq":1,"role":"board","stationId":"a","name":"A","code":null,"country":"SE","tz":"Europe/Stockholm","lat":1,"lon":1,"schedArr":null,"schedDep":null,"actualArr":null,"actualDep":null,"estimatedArr":null,"estimatedDep":null,"platform":null,"canceled":false,"deviations":["Elfel"],"reportSource":null}"#
        let old = try JSONDecoder().decode(LegStop.self, from: Data(json.utf8))
        #expect(old.causes == nil)
        #expect(en.causeNotes(old.allCauses) == ["Power fault"])
        let newer = json.replacingOccurrences(of: #""deviations":["Elfel"]"#, with: #""deviations":["Elfel"],"causes":[{"src":"trv","code":"ANA015","text":"Elfel"}]"#)
        let decoded = try JSONDecoder().decode(LegStop.self, from: Data(newer.utf8))
        #expect(decoded.causes == [LegStop.Cause(src: "trv", code: "ANA015", text: "Elfel")])
    }
}

@MainActor
struct DanishNoticeTests {
    private let l10n = L10n(language: .en)

    @Test func aLiftNoticeIsTranslatedWithItsStationAndPlatform() {
        let c = LegStop.Cause(src: "rejseplanen", text: "Elevatoren på Trekroner spor 3-4 er ude af drift", lang: "da")
        #expect(l10n.cause(c) == "Lift to platform 3–4 out of order at Trekroner")
        let plain = LegStop.Cause(src: "rejseplanen", text: "Elevatoren på Horsens er ude af drift", lang: "da")
        #expect(l10n.cause(plain) == "Lift out of order at Horsens")
        let two = LegStop.Cause(src: "rejseplanen", text: "Elevatoren på Sorgenfri spor 1og 2 er ude af drift", lang: "da")
        #expect(l10n.cause(two) == "Lift to platform 1 & 2 out of order at Sorgenfri")
    }

    @Test func facilityNoticesStayOffTheTrainsStopsAndUnknownDanishSaysSo() {
        let lift = LegStop.Cause(src: "rejseplanen", text: "Elevatoren på Horsens er ude af drift", lang: "da", facility: true)
        let other = LegStop.Cause(src: "rejseplanen", text: "Toget kører fra et andet spor", lang: "da")
        #expect(l10n.causeNotes([lift]) == [])
        #expect(l10n.facilityLines([lift]).map(\.text) == ["Lift out of order at Horsens"])
        #expect(l10n.causeLines([other]) == [CauseLine(text: "Toget kører fra et andet spor", lang: "da", original: nil)])
        // A known phrase is the app's own words: no language left to translate.
        #expect(l10n.causeLines([LegStop.Cause(src: "rejseplanen", text: "Signalfejl ved Fredericia", lang: "da")]).first?.lang == nil)
    }
}

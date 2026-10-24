//
//  NotificationsTests.swift
//  ClackTests
//

import Foundation
import Testing
@testable import Clack
@testable import ClackCore

struct NotificationsTests {
    private let oldSettings = """
    {"displayName":"","language":"en","distanceUnit":"km","clock":"24h","co2Comparison":"car_1","includeCommuter":true,
    "showRailNetwork":true,"theme":"dark","walkPace":"normal","stepFree":false,"heavyLuggage":false}
    """

    @Test func settingsSavedBeforeAlertsExistedStillLoadWithTheDefaults() throws {
        let s = try JSONDecoder().decode(Settings.self, from: Data(oldSettings.utf8))
        #expect(s.notify == false)
        #expect(s.notifyLeadMin == 60)
        #expect(s.notifyDelay && s.notifyPlatform && s.notifyCancel && s.notifyChange && s.notifyGetOff && s.notifyArrival)
    }

    @Test func aLeadTimeIsOneOfTheOffered() {
        #expect(Settings.defaults.applying(SettingsPatch(notifyLeadMin: 120))?.notifyLeadMin == 120)
        #expect(Settings.defaults.applying(SettingsPatch(notifyLeadMin: 0))?.notifyLeadMin == 0)
        #expect(Settings.defaults.applying(SettingsPatch(notifyLeadMin: 45)) == nil)
    }

    @Test func aPatchOnlySendsWhatChanged() throws {
        let data = try JSONEncoder().encode(SettingsPatch(notify: true, notifyDelay: false))
        let json = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        #expect(Set(json.keys) == ["notify", "notifyDelay"])
    }

    @Test func theServersTripCardStateDecodes() throws {
        let json = """
        {"status":"en_route","delayMin":6,"nextStop":"Alvesta","nextStopAt":1791634200000,"platform":"5","platformFor":"arrival",
        "progress":0.4,"departAt":1791631920000,"arriveAt":1791651120000,"canceled":false}
        """
        let state = try JSONDecoder().decode(TripActivityAttributes.ContentState.self, from: Data(json.utf8))
        #expect(state.delayMin == 6)
        #expect(state.nextStop == "Alvesta")
        #expect(state.progress == 0.4)
        // Nothing known is fine: the server sends nulls before a train has a position.
        let bare = """
        {"status":"scheduled","delayMin":null,"nextStop":null,"nextStopAt":null,"platform":null,"platformFor":"departure","progress":null,"departAt":1,"arriveAt":null,"canceled":false}
        """
        #expect(try JSONDecoder().decode(TripActivityAttributes.ContentState.self, from: Data(bare.utf8)).platform == nil)
    }

    @Test @MainActor func theNewPlatformEventHasWords() throws {
        let text = L10n().t("activity.platformSetDeparture", ["to": "5"])
        #expect(text == "Platform 5 announced for departure.")
        let types = try JSONDecoder().decode([LegEventType].self, from: Data(#"["platform_set"]"#.utf8))
        #expect(types == [.platformSet])
    }
}

struct CardPhaseTests {
    @Test func theCardStateDecodesTheServersMomentAndStillReadsAnOlderOne() throws {
        let json = """
        {"status":"arrived","delayMin":0,"nextStop":null,"nextStopAt":null,"platform":"3","platformFor":"arrival","progress":1,
        "departAt":1,"arriveAt":2,"canceled":false,"phase":"changing","note":null,"changePlatform":"5","changeAt":1791651120000}
        """
        let s = try JSONDecoder().decode(TripActivityAttributes.ContentState.self, from: Data(json.utf8))
        #expect(s.phase == "changing")
        #expect(s.changePlatform == "5")
        #expect(s.changeAt == 1_791_651_120_000)
        let old = """
        {"status":"en_route","delayMin":6,"nextStop":"Alvesta","nextStopAt":1,"platform":"5","platformFor":"arrival","progress":0.4,"departAt":1,"arriveAt":2,"canceled":false}
        """
        #expect(try JSONDecoder().decode(TripActivityAttributes.ContentState.self, from: Data(old.utf8)).phase == nil)
    }
}

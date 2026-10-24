//
//  FirstRunTests.swift
//  ClackTests
//

import Foundation
import Testing
@testable import ClackCore

struct FirstRunTests {
    @Test func theWelcomeIsForAnEmptyTripsTabTheFirstTime() {
        #expect(FirstRun.showsWelcome(seen: false, legs: 0))
        #expect(!FirstRun.showsWelcome(seen: true, legs: 0))
        // Trips already there (a new phone, the same id): no welcome.
        #expect(!FirstRun.showsWelcome(seen: false, legs: 3))
        // Not loaded yet: wait rather than flash it.
        #expect(!FirstRun.showsWelcome(seen: false, legs: nil))
    }

    @Test func aNewPhoneStaysOnTripsForTheWelcome() {
        #expect(FirstRun.holdsLanding(seen: false, legs: 0))
        #expect(!FirstRun.holdsLanding(seen: true, legs: 0))
        // Someone who already has trips (updating the app) lands where the rule says.
        #expect(!FirstRun.holdsLanding(seen: false, legs: 2))
    }

    @Test func theAlertsQuestionIsAskedOnceOnATripAhead() {
        #expect(FirstRun.showsAlertsPrompt(stageBefore: true, canceled: false, alertsOn: false, denied: false, asked: false))
        #expect(!FirstRun.showsAlertsPrompt(stageBefore: false, canceled: false, alertsOn: false, denied: false, asked: false))
        #expect(!FirstRun.showsAlertsPrompt(stageBefore: true, canceled: true, alertsOn: false, denied: false, asked: false))
        #expect(!FirstRun.showsAlertsPrompt(stageBefore: true, canceled: false, alertsOn: true, denied: false, asked: false))
        #expect(!FirstRun.showsAlertsPrompt(stageBefore: true, canceled: false, alertsOn: false, denied: true, asked: false))
        #expect(!FirstRun.showsAlertsPrompt(stageBefore: true, canceled: false, alertsOn: false, denied: false, asked: true))
    }

    @Test func alertsIntroShowsOnceWhileIOSHasNotAsked() {
        #expect(FirstRun.showsAlertsIntro(notDetermined: true, introSeen: false, welcomeDue: false))
        #expect(!FirstRun.showsAlertsIntro(notDetermined: true, introSeen: true, welcomeDue: false))
        #expect(!FirstRun.showsAlertsIntro(notDetermined: false, introSeen: false, welcomeDue: false))
        // iOS already allows alerts but Clack's switch is off (allowed from Test alerts, say): still worth the one ask.
        #expect(FirstRun.showsAlertsIntro(notDetermined: false, allowedButOff: true, introSeen: false, welcomeDue: false))
        // The welcome ends on the same page, so it isn't shown twice.
        #expect(!FirstRun.showsAlertsIntro(notDetermined: true, introSeen: false, welcomeDue: true))
    }
}

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
}

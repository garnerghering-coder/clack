//
//  Words.swift
//  Clack
//
//  Texts built from data that the app and its widgets both show.
//

import Foundation

extension L10n {
    /// What a milestone takes, in words ("10 journeys", "1,000 km", "First border crossing").
    /// `home` is the home country code for the "length of your country" medal; Sweden's (the server's fallback) when not given.
    public func milestoneLabel(_ m: Milestone, language: Language, home: String? = nil) -> String {
        let formatter = NumberFormatter()
        formatter.locale = Format.locale(language)
        formatter.numberStyle = .decimal
        let number = formatter.string(from: NSNumber(value: m.target)) ?? String(Int(m.target))
        switch m.family {
        case .distanceKm:
            if m.target >= 384_400 { return t("passport.milestone.moon") }
            if m.target >= 40_000, m.target < 100_000 { return t("passport.milestone.earth") }
            return t("passport.milestone.distanceKm", ["n": number])
        case .longestTrainKm:
            return t("passport.milestone.longestTrainKm", ["n": number])
        case .homeLength:
            return t("passport.milestone.homeLength", ["country": possessiveCountryName(home ?? "SE")])
        case .kindsOfTrain, .arcticCircle, .europeLength:
            return t("passport.milestone.\(m.family.rawValue)")
        case .unknown:
            // A family this build doesn't know (a newer server): a plain label rather than a missing key.
            return t("passport.milestone.unknown")
        case .journeys where m.target == 1:
            return t("passport.milestone.firstJourney")
        case .farNorth:
            return t("passport.milestone.farNorth", ["lat": String(Int(m.target) + 59)])
        case .earlyBird, .nightOwl, .weekender, .streak, .regular, .oresund, .highSpeedKm, .heritage, .longDay, .onTimeRun:
            // Polish pass 1's families: "{{n}} …", and a first one in words of its own where it reads better.
            let one = "passport.milestone.\(m.family.rawValue)One"
            if m.target == 1, t(one) != one { return t(one) }
            return t("passport.milestone.\(m.family.rawValue)", ["n": number])
        case .fourSeasons, .everyMonth, .capitals, .farSouth, .patient, .allNordics:
            return t("passport.milestone.\(m.family.rawValue)")
        default:
            return t("passport.milestone.\(m.family.rawValue)", count: Int(m.target))
        }
    }

    /// A country's name as it goes before "length" ("the length of Sweden", "Sveriges längd").
    public func possessiveCountryName(_ code: String) -> String {
        let key = "countries.possessive.\(code)"
        let text = t(key)
        return text == key ? countryName(code) : text
    }

    /// A country's name from its ISO code; the code itself when there is no name for it.
    public func countryName(_ code: String) -> String {
        let key = "countries.\(code)"
        let text = t(key)
        return text == key ? code : text
    }
}

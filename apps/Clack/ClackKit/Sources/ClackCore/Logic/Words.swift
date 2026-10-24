//
//  Words.swift
//  Clack
//
//  Texts built from data that the app and its widgets both show.
//

import Foundation

extension L10n {
    /// What a milestone takes, in words ("10 journeys", "1,000 km", "First border crossing").
    public func milestoneLabel(_ m: Milestone, language: Language) -> String {
        switch m.family {
        case .distanceKm:
            if m.target >= 40_000 { return t("passport.milestone.earth") }
            let formatter = NumberFormatter()
            formatter.locale = Format.locale(language)
            formatter.numberStyle = .decimal
            return t("passport.milestone.distanceKm", ["n": formatter.string(from: NSNumber(value: m.target)) ?? String(Int(m.target))])
        case .journeys where m.target == 1:
            return t("passport.milestone.firstJourney")
        default:
            return t("passport.milestone.\(m.family.rawValue)", count: Int(m.target))
        }
    }

    /// A country's name from its ISO code; the code itself when there is no name for it.
    public func countryName(_ code: String) -> String {
        let key = "countries.\(code)"
        let text = t(key)
        return text == key ? code : text
    }
}

//
//  OnboardView.swift
//  Clack
//

import ClackCore
import ClackDesign
import SwiftUI

/// On board (ADDITIONS_01 D): Trafikverket's facts for this departure first, then what the train typically has,
/// labelled "Typically" with where it comes from and when it was checked. Never a promise, never a guess.
struct OnboardView: View {
    @Environment(AppModel.self) private var app
    @Environment(L10n.self) private var l10n
    let facts: OnboardFacts?
    let operatorId: String?
    let trainType: String?
    var compact = false

    private static let icons: [String: String] = [
        "catering": "coffee", "wifi": "wifi", "power": "plug", "quiet_car": "volume-x", "first_class": "crown",
        "family_area": "baby", "pets_area": "paw-print", "bikes": "bike", "wheelchair_space": "accessibility",
        "step_free": "door-open", "accessible_toilet": "toilet", "sleeper": "bed-double",
    ]

    /// The amenities typical for this operator and type, with today's facts taking over for the same thing.
    private var typicalList: [(key: String, claim: AmenityClaim)] {
        let now = Date.now.timeIntervalSince1970 * 1000
        var typical = Onboard.typicalAmenities(app.amenities, operatorId: operatorId, typeId: trainType, now: now)
        if facts?.catering != nil || facts?.notices.contains("no_catering") == true { typical["catering"] = nil }
        if facts?.sleeper == true { typical["sleeper"] = nil }
        return Onboard.amenityKeys.compactMap { key in
            guard let claim = typical[key], claim.value != .flag(false) else { return nil }
            return (key, claim)
        }
    }

    var body: some View {
        let typicalList = typicalList
        let hasFacts = facts.map { $0.catering != nil || $0.sleeper || !$0.notices.isEmpty } ?? false
        if !hasFacts && typicalList.isEmpty {
            if !compact { Text(l10n.t("onboard.unknown")).clack(.caption).foregroundStyle(Ink.text2) }
        } else {
            VStack(alignment: .leading, spacing: 8) {
                if hasFacts, let facts { factChips(facts) }
                if !typicalList.isEmpty {
                    Text(l10n.t("onboard.typically")).clack(.captionUpper).foregroundStyle(Ink.text2)
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: compact ? 130 : 150), spacing: 12, alignment: .top)], alignment: .leading, spacing: 8) {
                        ForEach(typicalList, id: \.key) { entry in
                            HStack(alignment: .top, spacing: 8) {
                                LucideIcon(name: Self.icons[entry.key] ?? "info", size: 16).foregroundStyle(Ink.text2).padding(.top, 1)
                                (Text(label(entry.key, entry.claim)) + Text(entry.claim.note.map { !compact ? " · \($0)" : "" } ?? "").font(TextRole.caption.font).foregroundStyle(Ink.text2))
                                    .clack(.stopName).foregroundStyle(Ink.text)
                                Spacer(minLength: 0)
                            }
                        }
                    }
                }
            }
        }
    }

    private func label(_ key: String, _ claim: AmenityClaim) -> String {
        let base = l10n.t("onboard.keys.\(key)")
        switch claim.value {
        case .text(let text) where text != "partial": return "\(base): \(text)"
        case .text: return l10n.t("onboard.partial", ["what": base])
        case .flag: return base
        }
    }

    private func factChips(_ facts: OnboardFacts) -> some View {
        FlowLayout(spacing: 8, lineSpacing: 8) {
            if let catering = facts.catering {
                let what = l10n.t("onboard.catering.\(catering)")
                factChip("coffee", facts.cateringCar.map { l10n.t("onboard.cateringInCar", ["what": what, "car": $0]) } ?? what, tint: Ink.text)
            }
            if facts.sleeper { factChip("bed-double", l10n.t("onboard.keys.sleeper"), tint: Ink.text) }
            ForEach(facts.notices, id: \.self) { notice in factChip("triangle-alert", l10n.t("onboard.notices.\(notice)"), tint: Ink.warnText, iconTint: Ink.warnText) }
        }
    }

    private func factChip(_ icon: String, _ text: String, tint: Color, iconTint: Color = Ink.text2) -> some View {
        HStack(spacing: 4) {
            LucideIcon(name: icon, size: 14).foregroundStyle(iconTint)
            Text(text)
        }
        .clack(.chip).foregroundStyle(tint)
    }
}

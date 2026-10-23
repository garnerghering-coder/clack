//
//  OnboardView.swift
//  Clack
//

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

    private func host(_ url: String) -> String {
        guard let host = URL(string: url)?.host else { return url }
        return host.hasPrefix("www.") ? String(host.dropFirst(4)) : host
    }

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
                                (Text(label(entry.key, entry.claim)) + Text(entry.claim.note.map { !compact ? " · \($0)" : "" } ?? "").font(ClackFont.inter(13)).foregroundColor(Ink.text2))
                                    .clack(.stopName).foregroundStyle(Ink.text)
                                Spacer(minLength: 0)
                            }
                        }
                    }
                    if !compact { sourceLine(typicalList) }
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
        FlowLayout(spacing: 6, lineSpacing: 6) {
            if let catering = facts.catering {
                let what = l10n.t("onboard.catering.\(catering)")
                factChip("coffee", facts.cateringCar.map { l10n.t("onboard.cateringInCar", ["what": what, "car": $0]) } ?? what, tint: Ink.text)
            }
            if facts.sleeper { factChip("bed-double", l10n.t("onboard.keys.sleeper"), tint: Ink.text) }
            ForEach(facts.notices, id: \.self) { notice in factChip("triangle-alert", l10n.t("onboard.notices.\(notice)"), tint: Ink.warnText, iconTint: Ink.warnText) }
        }
    }

    private func factChip(_ icon: String, _ text: String, tint: Color, iconTint: Color = Ink.text2) -> some View {
        HStack(spacing: 5) {
            LucideIcon(name: icon, size: 14).foregroundStyle(iconTint)
            Text(text)
        }
        .clack(.chip).foregroundStyle(tint)
    }

    private func sourceLine(_ list: [(key: String, claim: AmenityClaim)]) -> some View {
        var seen = Set<String>()
        let sources = list.map(\.claim).filter { seen.insert(host($0.source)).inserted }
        let checked = sources.first.flatMap { Format.isoToMidnightMs($0.verified) }
        var text = AttributedString(l10n.t("onboard.source") + " ")
        for (index, claim) in sources.enumerated() {
            if index > 0 { text += AttributedString(", ") }
            var link = AttributedString(host(claim.source))
            link.link = URL(string: claim.source)
            link.foregroundColor = Ink.accentInk
            link.font = ClackFont.inter(13, .semibold)
            text += link
        }
        if let checked {
            text += AttributedString(" · " + l10n.t("onboard.checked", ["date": Format.day(checked, tz: "Europe/Stockholm", language: app.settings.language)]))
        }
        return Text(text).clack(.caption).foregroundStyle(Ink.text2)
    }
}

/// Lays its children out in rows, wrapping to the next row when one doesn't fit (flex-wrap).
struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    var lineSpacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        arrange(proposal: proposal, subviews: subviews).size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrange(proposal: proposal, subviews: subviews)
        for (index, frame) in result.frames.enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + frame.minX, y: bounds.minY + frame.minY), proposal: ProposedViewSize(frame.size))
        }
    }

    private func arrange(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, frames: [CGRect]) {
        let maxWidth = proposal.width ?? .infinity
        var frames: [CGRect] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var width: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > 0 && x + size.width > maxWidth {
                x = 0
                y += rowHeight + lineSpacing
                rowHeight = 0
            }
            frames.append(CGRect(x: x, y: y, width: size.width, height: size.height))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
            width = max(width, x - spacing)
        }
        return (CGSize(width: width, height: y + rowHeight), frames)
    }
}

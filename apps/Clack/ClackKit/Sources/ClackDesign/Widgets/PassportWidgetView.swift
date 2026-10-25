//
//  PassportWidgetView.swift
//  ClackDesign
//
//  The passport card on the holographic foil yellow. Static: a widget can't read the gyroscope. Numbers never shrink
//  past `WidgetInsets.minimumScale`: a smaller type role is tried first.
//

import ClackCore
import SwiftUI

/// Yellow, with a pearly foil sweep and a soft sheen, like the card on the Passport tab (metallic, not neon).
public struct FoilBackground: View {
    public init() {}

    /// Soft pink, lilac, ice blue, mint, champagne: the Passport card's foil.
    private static let pearl: [Color] = [
        Color(red: 0.95, green: 0.77, blue: 0.89), Color(red: 0.80, green: 0.74, blue: 0.95), Color(red: 0.73, green: 0.86, blue: 0.95),
        Color(red: 0.77, green: 0.93, blue: 0.84), Color(red: 0.96, green: 0.90, blue: 0.72), Color(red: 0.95, green: 0.77, blue: 0.89),
    ]

    public var body: some View {
        ZStack {
            Ink.accent
            LinearGradient(colors: Self.pearl.map { $0.opacity(0.22) }, startPoint: .topLeading, endPoint: .bottomTrailing)
                .blendMode(.overlay)
            LinearGradient(colors: [Ink.onTint.opacity(0), Ink.onTint.opacity(0.55), Ink.onTint.opacity(0)], startPoint: UnitPoint(x: 0.1, y: 0), endPoint: UnitPoint(x: 0.7, y: 1))
        }
    }
}

public struct PassportWidgetView: View {
    var snapshot: WidgetSnapshot
    var date: Date
    var size: WidgetSize
    var isPlaceholder: Bool

    public init(snapshot: WidgetSnapshot, date: Date, size: WidgetSize, isPlaceholder: Bool = false) {
        self.snapshot = snapshot
        self.date = date
        self.size = size
        self.isPlaceholder = isPlaceholder
    }

    private var l10n: L10n { WidgetWords.l10n(snapshot.language) }
    private var ink: Color { Ink.onAccent }

    public var body: some View {
        Group {
            if let b = snapshot.passport {
                card(b)
            } else {
                EmptyWidget(title: l10n.t("passport.emptyTitle"), hint: l10n.t("widgets.openApp"))
            }
        }
        .environment(l10n)
        .placeholder(isPlaceholder)
    }

    /// Kilometres in the app's unit.
    private func distance(_ km: Double) -> Double { snapshot.distanceUnit == .mi ? km * 1000 / 1609.344 : km }
    private var unit: String { snapshot.distanceUnit == .mi ? "mi" : "km" }

    private func number(_ n: Double) -> String {
        let f = NumberFormatter()
        f.locale = Format.locale(snapshot.language)
        f.numberStyle = .decimal
        f.maximumFractionDigits = 0
        return f.string(from: NSNumber(value: n.rounded())) ?? String(Int(n.rounded()))
    }

    /// A value over its label. `roles` from the largest: the first the value fits in whole.
    private func big(_ value: String, _ label: String, roles: [TextRole]) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            ViewThatFits(in: .horizontal) {
                ForEach(Array(roles.enumerated()), id: \.offset) { _, role in
                    Text(value).clack(role).lineLimit(1).fixedSize()
                }
                Text(value).clack(roles.last ?? .walkBig).lineLimit(1).minimumScaleFactor(WidgetInsets.minimumScale)
            }
            .foregroundStyle(ink)
            FittingText(label).clack(.captionUpper).foregroundStyle(ink.opacity(0.65))
        }
    }

    private func ring(_ b: WidgetSnapshot.PassportBits) -> some View {
        let fraction = min(1, max(0, (b.nextMedalValue ?? 0) / max(1, b.nextMedalTarget ?? 1)))
        return ZStack {
            Circle().stroke(ink.opacity(0.18), lineWidth: 6)
            Circle().trim(from: 0, to: fraction).stroke(ink, style: StrokeStyle(lineWidth: 6, lineCap: .round)).rotationEffect(.degrees(-90))
            LucideIcon(name: "star", size: 18).foregroundStyle(ink)
        }
    }

    private func updated() -> some View {
        UpdatedLine(updatedAt: snapshot.passportUpdatedAt, now: date, l10n: l10n, clock: snapshot.clock)
    }

    /// "PASSPORT" and "Updated 12:04" on one line, or the second under the first.
    private var titleLine: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 8) {
                Text(l10n.t("passport.title")).clack(.captionUpper).foregroundStyle(ink.opacity(0.7)).fixedSize()
                Spacer(minLength: 0)
                updated()
            }
            VStack(alignment: .leading, spacing: 0) {
                Text(l10n.t("passport.title")).clack(.captionUpper).foregroundStyle(ink.opacity(0.7))
                updated()
            }
        }
    }

    /// Counts side by side, in the largest role at which all of them fit whole.
    private func counts(_ items: [(String, String)], roles: [TextRole]) -> some View {
        ViewThatFits(in: .horizontal) {
            ForEach(roles.indices, id: \.self) { i in
                HStack(spacing: 16) {
                    ForEach(items, id: \.1) { value, label in big(value, label, roles: [roles[i]]).fixedSize() }
                }
            }
            HStack(spacing: 12) {
                ForEach(items, id: \.1) { value, label in big(value, label, roles: [roles.last ?? .bigUnit]) }
            }
        }
    }

    private func card(_ b: WidgetSnapshot.PassportBits) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            titleLine
            switch size {
            case .small:
                Spacer(minLength: 0)
                big(number(distance(b.km)), unit, roles: [.passportBig, .walkBig])
                big(String(b.trains), l10n.t("passport.trains"), roles: [.bigTime])
            case .medium:
                HStack(alignment: .center, spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        big(number(distance(b.km)), unit, roles: [.passportBig, .walkBig])
                        counts([
                            (String(b.trains), l10n.t("passport.trains")),
                            (String(b.stations), l10n.t("passport.stations")),
                            (String(b.countries), l10n.t("passport.countries")),
                        ], roles: [.walkBig, .bigUnit])
                    }
                    .layoutPriority(1)
                    Spacer(minLength: 0)
                    if b.nextMedal != nil { ring(b).frame(width: 56, height: 56) }
                }
            case .large:
                HStack(alignment: .top, spacing: 16) {
                    VStack(alignment: .leading, spacing: 12) {
                        big(number(distance(b.km)), unit, roles: [.passportDistance, .passportBig])
                        counts([(String(b.trains), l10n.t("passport.trains")), (String(b.journeys), l10n.t("passport.journeys"))],
                               roles: [.walkBig, .bigUnit])
                        counts([(String(b.stations), l10n.t("passport.stations")), (String(b.countries), l10n.t("passport.countries"))],
                               roles: [.walkBig, .bigUnit])
                    }
                    .layoutPriority(1)
                    Spacer(minLength: 0)
                    if let medal = b.nextMedal {
                        VStack(spacing: 4) {
                            ring(b).frame(width: 64, height: 64)
                            Text(medal).clack(.chip).foregroundStyle(ink).multilineTextAlignment(.center)
                                .lineLimit(3).minimumScaleFactor(WidgetInsets.minimumScale)
                            Text(l10n.t("widgets.nextMedal")).clack(.captionUpper).foregroundStyle(ink.opacity(0.65))
                                .multilineTextAlignment(.center).lineLimit(2)
                        }
                        .frame(maxWidth: 96)
                    }
                }
                Spacer(minLength: 0)
                Rectangle().fill(ink.opacity(0.2)).frame(height: 1)
                HStack(spacing: 24) {
                    if let pct = b.onTimePct { big("\(Int(pct.rounded()))%", l10n.t("widgets.onTime"), roles: [.walkBig, .bigUnit]) }
                    if let kg = b.co2SavedKg { big("\(number(kg)) kg", l10n.t("widgets.co2Saved"), roles: [.walkBig, .bigUnit]) }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

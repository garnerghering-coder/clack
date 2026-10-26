//
//  PassportCard.swift
//  Clack
//

import ClackCore
import ClackDesign
import SwiftUI

/// Lives with the design system: it is artwork (a yellow passport cover in its own fixed inks), like the medals.
///
/// The Passport's top card: a passport page (gradient, guilloche, sheen) that tilts and catches the light as you move the
/// phone. It has no touch handling, so the page scrolls from anywhere on it.
struct PassportCard: View {
    @Environment(AppModel.self) private var app
    @Environment(L10n.self) private var l10n
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let data: Passport
    let year: Int?
    @Binding var flavorIndex: Int
    @State private var motion = MotionTilt()
    @State private var sheen = false

    var body: some View {
        let t = data.totals
        let unit = app.settings.distanceUnit
        let km = t.distanceM / 1000
        let shown = unit == .mi ? km / 1.609344 : km
        let formatter = NumberFormatter()
        let _ = { formatter.locale = Format.locale(app.settings.language); formatter.numberStyle = .decimal; formatter.maximumFractionDigits = 0 }()
        let flavors = flavorLines
        let ink = Ink.onAccent
        let soft = Color(red: 10 / 255, green: 10 / 255, blue: 10 / 255).opacity(0.62)
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(l10n.t("passport.railPassport")).clack(.captionUpper).foregroundStyle(soft)
                    Text(year.map { l10n.t("passport.yearPassport", ["year": String($0)]) } ?? l10n.t("passport.allTimePassport"))
                        .font(ClackFont.inter(15, .heavy)).tracking(0.3).foregroundStyle(ink)
                }
                Spacer(minLength: 0)
                LucideIcon(name: "train-front", size: 22)
                    .foregroundStyle(Color.black.opacity(0.75))
                    .frame(width: 44, height: 44)
                    .overlay(Circle().strokeBorder(Color.black.opacity(0.55), lineWidth: 2))
                    .overlay(Circle().strokeBorder(Color.white.opacity(0.25), lineWidth: 4).padding(2))
                    .accessibilityHidden(true)
            }
            (Text(formatter.string(from: NSNumber(value: shown.rounded())) ?? "0") + Text(" \(unit.rawValue)").font(ClackFont.grotesk(22)).foregroundColor(soft))
                .clack(.passportDistance).monospacedDigit().foregroundStyle(ink)
            if !flavors.isEmpty {
                Button { flavorIndex += 1 } label: {
                    Text(flavors[flavorIndex % flavors.count]).clack(.rowTitle).foregroundStyle(ink).multilineTextAlignment(.leading)
                }
                .buttonStyle(.plain)
                .accessibilityHint(l10n.t("passport.nextFact"))
            }
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                tile(String(t.trains), l10n.t("passport.trains"), soft: soft, ink: ink)
                tile(String(t.journeys), l10n.t("passport.journeys"), soft: soft, ink: ink)
                tile(Format.duration(t.minutes), l10n.t("passport.timeOnTrains"), soft: soft, ink: ink)
                tile(String(t.stations), l10n.t("passport.stations"), soft: soft, ink: ink)
            }
            .padding(.top, 6)
            // A machine-readable-zone look, spelled out from your own totals (decoration; nothing personal).
            Text(mrz(km: km))
                .font(.system(size: 11, design: .monospaced)).tracking(1.3).foregroundStyle(Color.black.opacity(0.45))
                .lineLimit(1)
                .padding(.top, 8)
                .overlay(alignment: .top) { Rectangle().stroke(Color.black.opacity(0.2), style: StrokeStyle(lineWidth: 1, dash: [3, 3])).frame(height: 1) }
                .padding(.top, 4)
                .accessibilityHidden(true)
        }
        .padding(.top, 20).padding(.horizontal, 20).padding(.bottom, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background { cover }
        .clipShape(RoundedRectangle(cornerRadius: Radius.sheet, style: .continuous))
        // A plain shadow: the yellow glow made it read as neon (owner, 2026-10-25). The card stays still; only the foil
        // and the glint move with the phone.
        .clackShadow()
        .onAppear { if !reduceMotion { motion.start() } }
        .onDisappear { motion.stop() }
        .onAppear { sheen = true }
    }

    /// The yellow passport cover with its holographic surface; the foil and glint follow the phone (Holo.swift).
    private var cover: some View {
        PassportCover(shine: motion.shine, sweep: sheen)
            .overlay(RoundedRectangle(cornerRadius: Radius.sheet, style: .continuous).strokeBorder(Color.white.opacity(0.35), lineWidth: 1).blendMode(.overlay))
    }

    private func tile(_ value: String, _ title: String, soft: Color, ink: Color) -> some View {
        Tile(label: title, value: value, tone: .onAccent)
    }

    private func mrz(km: Double) -> String {
        PassportMRZ.line(year: year, km: km, journeys: data.totals.journeys, stations: data.totals.stations, countries: data.totals.countries)
    }

    /// The facts that rotate under the distance when tapped; ones with nothing worth saying are left out.
    private var flavorLines: [String] {
        let f = data.flavor
        let t = data.totals
        var out: [String] = []
        // Under one lap a share reads better than "0.04×"; tiny distances get no comparison at all.
        if f.earthLaps >= 1 { out.append(l10n.t("passport.flavor.earth", ["n": String(format: "%.1f", f.earthLaps)])) }
        else if f.earthLaps >= 0.01 { out.append(l10n.t("passport.flavor.earthPct", ["pct": String(Int((f.earthLaps * 100).rounded()))])) }
        // The length of your own country (an older server only sends Sweden's), then how far across Europe.
        if let home = f.homeLengths {
            if home >= 0.05 { out.append(l10n.t("passport.flavor.home", ["n": String(format: "%.1f", home), "country": l10n.possessiveCountryName(data.home ?? "SE")])) }
        } else if f.swedenLengths >= 0.05 {
            out.append(l10n.t("passport.flavor.sweden", ["n": String(format: "%.1f", f.swedenLengths)]))
        }
        if let europe = f.europeLengths {
            if europe >= 1 { out.append(l10n.t("passport.flavor.europe", ["n": String(format: "%.1f", europe)])) }
            else if europe >= 0.01 { out.append(l10n.t("passport.flavor.europePct", ["pct": String(Int((europe * 100).rounded()))])) }
        }
        if t.minutes > 0 { out.append(l10n.t("passport.flavor.time", ["time": Format.duration(t.minutes)])) }
        if let route = f.topRoute { out.append(l10n.t("passport.flavor.route", count: route.count, ["route": route.route])) }
        if let month = f.busiestMonth, let ms = Format.isoToNoonMs("\(month.month)-15") {
            out.append(l10n.t("passport.flavor.month", count: month.count, ["month": Format.month(ms, tz: "UTC", language: app.settings.language)]))
        }
        if f.lateMinutes >= 30 { out.append(l10n.t("passport.flavor.late", ["time": Format.duration(f.lateMinutes)])) }
        return out
    }
}

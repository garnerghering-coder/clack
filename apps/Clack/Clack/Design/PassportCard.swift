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

    /// A holographic foil: a pearly spectrum (soft pink, lilac, ice blue, mint, champagne, like the foil stamped into a
    /// real passport, not a neon rainbow) that slides across the cover as the phone moves, strongest along the guilloche
    /// lines with a faint wash over the rest. Still with Reduce Motion.
    private var foil: some View {
        let t = reduceMotion ? 0.5 : motion.shine
        let pearl = LinearGradient(
            colors: [Color(hex: "#f3c4e4")!, Color(hex: "#cdbdf2")!, Color(hex: "#b9dcf2")!, Color(hex: "#c4ecd6")!, Color(hex: "#f4e6b8")!, Color(hex: "#f3c4e4")!],
            startPoint: UnitPoint(x: t - 0.6, y: 0), endPoint: UnitPoint(x: t + 0.6, y: 1)
        )
        return ZStack {
            pearl.opacity(0.14)
            pearl.mask(Guilloche()).opacity(0.45)
        }
        .blendMode(.overlay)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    /// Signal yellow deepening to amber, lit from the top left like a passport cover under a lamp, with guilloche lines,
    /// holographic foil and a sheen.
    private var cover: some View {
        ZStack {
            CSSLinearGradient(angle: 155, stops: [
                .init(color: Color(hex: "#ffe169")!, location: 0), .init(color: Color(hex: "#f8d64a")!, location: 0.45), .init(color: Color(hex: "#eab21c")!, location: 1),
            ])
            CSSRadialGradient(rx: 0.9, ry: 0.9, cx: 1, cy: 1, stops: [.init(color: Color(hex: "#d99a00")!, location: 0), .init(color: Color(hex: "#d99a00")!.opacity(0), location: 0.6)])
            CSSRadialGradient(rx: 1.2, ry: 0.8, cx: 0, cy: 0, stops: [.init(color: Color(hex: "#fff3b0")!, location: 0), .init(color: Color(hex: "#fff3b0")!.opacity(0), location: 0.55)])
            Guilloche().opacity(0.16)
            foil
            GeometryReader { proxy in
                LinearGradient(stops: [.init(color: .clear, location: 0.3), .init(color: .white.opacity(0.75), location: 0.45), .init(color: .clear, location: 0.6)], startPoint: .leading, endPoint: .trailing)
                    .frame(width: proxy.size.width * 2.5)
                    .offset(x: sheen || reduceMotion ? -proxy.size.width * 2.5 * 0.45 + proxy.size.width * (reduceMotion ? 0.3 : motion.shine) : proxy.size.width * 0.4)
                    .blendMode(.overlay)
                    .animation(reduceMotion ? nil : .easeOut(duration: 1.6).delay(0.3), value: sheen)
                // The metallic glint: a narrow bright line that runs ahead of the sheen as the phone tilts.
                LinearGradient(stops: [.init(color: .clear, location: 0.46), .init(color: .white.opacity(0.9), location: 0.5), .init(color: .clear, location: 0.54)], startPoint: .topLeading, endPoint: .bottomTrailing)
                    .frame(width: proxy.size.width * 2)
                    .offset(x: -proxy.size.width + proxy.size.width * 1.6 * (reduceMotion ? 0.3 : motion.shine))
                    .blendMode(.softLight)
                    .allowsHitTesting(false)
            }
        }
        .overlay(RoundedRectangle(cornerRadius: Radius.sheet, style: .continuous).strokeBorder(Color.white.opacity(0.35), lineWidth: 1).blendMode(.overlay))
    }

    private func tile(_ value: String, _ title: String, soft: Color, ink: Color) -> some View {
        Tile(label: title, value: value, tone: .onAccent)
    }

    private func mrz(km: Double) -> String {
        let t = data.totals
        let text = "P<CLACK<<\(year.map(String.init) ?? "ALL")<<KM\(Int(km.rounded()))<<J\(t.journeys)<<S\(t.stations)<<C\(t.countries)"
        return String((text + String(repeating: "<", count: 44)).prefix(44))
    }

    /// The facts that rotate under the distance when tapped; ones with nothing worth saying are left out.
    private var flavorLines: [String] {
        let f = data.flavor
        let t = data.totals
        var out: [String] = []
        // Under one lap a share reads better than "0.04×"; tiny distances get no comparison at all.
        if f.earthLaps >= 1 { out.append(l10n.t("passport.flavor.earth", ["n": String(format: "%.1f", f.earthLaps)])) }
        else if f.earthLaps >= 0.01 { out.append(l10n.t("passport.flavor.earthPct", ["pct": String(Int((f.earthLaps * 100).rounded()))])) }
        if f.swedenLengths >= 0.05 { out.append(l10n.t("passport.flavor.sweden", ["n": String(format: "%.1f", f.swedenLengths)])) }
        if t.minutes > 0 { out.append(l10n.t("passport.flavor.time", ["time": Format.duration(t.minutes)])) }
        if let route = f.topRoute { out.append(l10n.t("passport.flavor.route", count: route.count, ["route": route.route])) }
        if let month = f.busiestMonth, let ms = Format.isoToNoonMs("\(month.month)-15") {
            out.append(l10n.t("passport.flavor.month", count: month.count, ["month": Format.month(ms, tz: "UTC", language: app.settings.language)]))
        }
        if f.lateMinutes >= 30 { out.append(l10n.t("passport.flavor.late", ["time": Format.duration(f.lateMinutes)])) }
        return out
    }
}

private extension Double {
    func clamped(_ lower: Double, _ upper: Double) -> Double { Swift.min(Swift.max(self, lower), upper) }
}

/// Fine concentric lines, the security-print pattern on passports and banknotes.
private struct Guilloche: View {
    var body: some View {
        Canvas { context, size in
            let ink = Color(red: 120 / 255, green: 70 / 255, blue: 0)
            func rings(_ cx: Double, _ cy: Double, step: Double, alpha: Double) {
                let maxR = hypot(size.width * 1.8, size.height * 1.8)
                var r = step
                while r < maxR {
                    context.stroke(Path(ellipseIn: CGRect(x: cx - r, y: cy - r, width: r * 2, height: r * 2)), with: .color(ink.opacity(alpha)), lineWidth: 1)
                    r += step + 1
                }
            }
            rings(size.width * 0.78, size.height * 0.2, step: 9, alpha: 0.9)
            rings(size.width * 0.1, size.height * 0.95, step: 13, alpha: 0.7)
        }
        .mask(LinearGradient(colors: [.black, .black.opacity(0.35)], startPoint: .top, endPoint: .bottom))
        .allowsHitTesting(false)
    }
}


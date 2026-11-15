//
//  RecapShareCard.swift
//  Clack
//

import ClackCore
import ClackDesign
import SwiftUI

// MARK: the year's twelve months (Year in Rail and its share card)

/// One month of a year, with nothing left out: a month without trains is still there, with 0.
struct RecapMonth: Hashable, Identifiable {
    /// `YYYY-MM`, as the Passport's months.
    let key: String
    /// "Mar" / "Mars", in the app's language.
    let short: String
    /// "March" / "Mars".
    let long: String
    let trains: Int
    let distanceM: Double
    var id: String { key }

    /// All twelve months of `year`, January first, from the Passport's months (which only list months with trains).
    static func year(_ year: Int, _ months: [Passport.Month]?, language: Language) -> [RecapMonth] {
        let byMonth = Dictionary((months ?? []).map { ($0.month, $0) }, uniquingKeysWith: { first, _ in first })
        let formatter = DateFormatter()
        formatter.locale = Format.locale(language)
        let shorts = formatter.shortStandaloneMonthSymbols ?? []
        let longs = formatter.standaloneMonthSymbols ?? []
        return (1...12).map { m in
            let key = String(format: "%04d-%02d", year, m)
            let row = byMonth[key]
            return RecapMonth(
                key: key,
                short: (m - 1 < shorts.count ? shorts[m - 1] : String(m)).capitalized(with: formatter.locale),
                long: (m - 1 < longs.count ? longs[m - 1] : String(m)).capitalized(with: formatter.locale),
                trains: row?.trains ?? 0,
                distanceM: row?.distanceM ?? 0
            )
        }
    }
}

/// One month: its short name, the trains in it, and a thin bar measured against the busiest month. The picked (or
/// busiest) month is filled in ink with the yellow on it; an empty month is faded, never dropped. `scale` draws it
/// bigger for the share card; `grow` (0…1) lets the bar fill in.
struct RecapMonthCell: View {
    let month: RecapMonth
    /// The busiest month's trains (the bar's full length).
    let peak: Int
    let highlighted: Bool
    var scale: CGFloat = 1
    var grow: Double = 1

    var body: some View {
        let fg = highlighted ? Ink.brandYellow : Ink.onAccent
        let fraction = peak > 0 ? Double(month.trains) / Double(peak) : 0
        VStack(alignment: .leading, spacing: Space.xs * scale) {
            Text(verbatim: month.short)
                .font(ClackFont.inter(13 * scale, .semibold, relativeTo: .footnote))
                .lineLimit(1).minimumScaleFactor(0.6)
            Text(verbatim: String(month.trains))
                .font(ClackFont.grotesk(26 * scale, relativeTo: .title2)).monospacedDigit()
                .lineLimit(1).minimumScaleFactor(0.5)
            RoundedRectangle(cornerRadius: Radius.bar * scale)
                .fill(fg.opacity(0.2))
                .frame(height: 4 * scale)
                .overlay(alignment: .leading) {
                    RoundedRectangle(cornerRadius: Radius.bar * scale)
                        .fill(fg)
                        .scaleEffect(x: fraction * grow, y: 1, anchor: .leading)
                }
        }
        .foregroundStyle(fg)
        .opacity(month.trains == 0 && !highlighted ? 0.45 : 1)
        .padding(Space.s * scale)
        .frame(maxWidth: .infinity, minHeight: 56 * scale, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: Radius.input * scale, style: .continuous)
                .fill(highlighted ? Ink.onAccent : Ink.onAccent.opacity(0.08))
        )
    }
}

/// The twelve months, four across and three down. With `onPick` each month is a button (`label` is what VoiceOver
/// reads for it); without, it is a picture (the share card).
struct RecapMonthGrid: View {
    let months: [RecapMonth]
    /// The month drawn filled.
    let highlighted: String?
    var scale: CGFloat = 1
    var grow: Double = 1
    var label: ((RecapMonth) -> String)?
    var onPick: ((RecapMonth) -> Void)?

    var body: some View {
        let peak = months.map(\.trains).max() ?? 0
        VStack(spacing: Space.s * scale) {
            ForEach(0..<3, id: \.self) { row in
                HStack(spacing: Space.s * scale) {
                    ForEach(months.dropFirst(row * 4).prefix(4)) { m in
                        cell(m, peak: peak)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func cell(_ m: RecapMonth, peak: Int) -> some View {
        let picture = RecapMonthCell(month: m, peak: peak, highlighted: m.key == highlighted, scale: scale, grow: grow)
        if let onPick {
            Button { onPick(m) } label: { picture }
                .buttonStyle(.press(radius: Radius.input))
                .accessibilityLabel(label?(m) ?? m.long)
                .accessibilityAddTraits(m.key == highlighted ? .isSelected : [])
        } else {
            picture
        }
    }
}

// MARK: the share card

/// Lives with the design system: artwork rendered to a fixed-size image (ImageRenderer at scale 1), the same whatever
/// the theme, so it keeps fixed pixel sizes and no animation, like `ShareCardView`.
///
/// The story card, 1080 × 1920 (9:16), in the Year in Rail's look: the Passport's yellow, ink type, the year's months
/// as twelve tiles, the trains' drawings and the medals. Four kinds: a year, all time, one journey, one medal. Only
/// what the Passport and the trip say; a part with nothing to say is left out. No times of day, ticket details or train
/// numbers (share.privacyMore).
struct RecapShareCard: View {
    static let width: CGFloat = 1080
    static let height: CGFloat = 1920
    private static let margin: CGFloat = 88
    /// Where the medals' foil light sits, frozen (as on ShareCardView).
    private static let shine = 0.35
    private static let ink = Ink.onAccent
    private static let soft = Ink.onAccent.opacity(0.65)

    struct Stat: Hashable { var value: String; var label: String }
    struct Train: Hashable { var type: TrainType; var operatorId: String?; var count: String }
    struct CardMedal: Hashable { var milestone: Milestone; var label: String }

    /// A year (with its months) or all time (without).
    struct Recap {
        var kicker: String
        var distance: String
        var unit: String
        /// "12" and "trains, in 5 journeys and 3 h on board."
        var trainsCount: String
        var trainsLine: String
        var monthsTitle: String?
        var months: [RecapMonth]?
        var route: String?
        var routeLine: String?
        var trainsTitle: String?
        var trains: [Train]
        var medals: [CardMedal]
    }

    struct Journey {
        var kicker: String
        var train: TrainType?
        var operatorId: String?
        var title: String
        var distance: String
        var unit: String
        var stats: [Stat]
        var medals: [CardMedal]
    }

    struct MedalCard {
        var kicker: String
        var medal: CardMedal
        var sub: String?
        var stats: [Stat]
    }

    enum Content {
        case recap(Recap)
        case journey(Journey)
        case medal(MedalCard)
    }

    let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            switch content {
            case .recap(let r): recap(r)
            case .journey(let j): journey(j)
            case .medal(let m): medal(m)
            }
            Spacer(minLength: 0)
            Wordmark(fontSize: 40)
        }
        .padding(.horizontal, Self.margin)
        .padding(.top, 112)
        .padding(.bottom, 96)
        .frame(width: Self.width, height: Self.height, alignment: .topLeading)
        .background(Ink.brandYellow)
        .clipped()
    }

    // MARK: kinds

    private func recap(_ r: Recap) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            kicker(r.kicker)
            hero(r.distance, r.unit).padding(.top, 8)
            (Text(verbatim: "\(r.trainsCount) ").fontWeight(.heavy) + Text(verbatim: r.trainsLine))
                .font(ClackFont.inter(40, .semibold)).foregroundStyle(Self.ink)
                .lineLimit(3).minimumScaleFactor(0.7).fixedSize(horizontal: false, vertical: true)
            if let months = r.months {
                if let title = r.monthsTitle { section(title).padding(.top, 52) }
                let busiest = months.max { $0.trains < $1.trains }.flatMap { $0.trains > 0 ? $0.key : nil }
                RecapMonthGrid(months: months, highlighted: busiest, scale: 2.2)
                    .padding(.top, 20)
            }
            if let route = r.route {
                Text(verbatim: route).font(ClackFont.grotesk(60)).foregroundStyle(Self.ink)
                    .lineLimit(2).minimumScaleFactor(0.6).padding(.top, 52)
                if let line = r.routeLine {
                    Text(verbatim: line).font(ClackFont.inter(32, .semibold)).foregroundStyle(Self.soft).padding(.top, 6)
                }
            }
            if !r.trains.isEmpty {
                if let title = r.trainsTitle { section(title).padding(.top, 52) }
                HStack(alignment: .bottom, spacing: 32) {
                    ForEach(r.trains.prefix(3), id: \.self) { t in
                        VStack(alignment: .leading, spacing: 10) {
                            TrainPicture(type: t.type, operatorId: t.operatorId, height: 80)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            Text(verbatim: t.type.name).font(ClackFont.inter(26, .bold)).foregroundStyle(Self.ink)
                                .lineLimit(2).minimumScaleFactor(0.7)
                            Text(verbatim: t.count).font(ClackFont.grotesk(40)).monospacedDigit().foregroundStyle(Self.ink)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(.top, 20)
            }
            medals(r.medals, size: 140).padding(.top, 52)
        }
    }

    private func journey(_ j: Journey) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            kicker(j.kicker)
            if let train = j.train {
                TrainPicture(type: train, operatorId: j.operatorId, height: 180)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 72)
                Text(verbatim: train.name).font(ClackFont.inter(34, .bold)).foregroundStyle(Self.soft).padding(.top, 20)
            }
            Text(verbatim: j.title).font(ClackFont.grotesk(92)).foregroundStyle(Self.ink)
                .lineLimit(3).minimumScaleFactor(0.5).fixedSize(horizontal: false, vertical: true)
                .padding(.top, 64)
            hero(j.distance, j.unit).padding(.top, 40)
            statsRow(j.stats, center: false).padding(.top, 40)
            medals(j.medals, size: 160).padding(.top, 72)
        }
    }

    private func medal(_ m: MedalCard) -> some View {
        VStack(spacing: 0) {
            kicker(m.kicker).frame(maxWidth: .infinity, alignment: .leading)
            Medal(m: m.medal.milestone, size: 600, foil: Self.shine).padding(.top, 120)
            Text(verbatim: m.medal.label).font(ClackFont.grotesk(84)).foregroundStyle(Self.ink).multilineTextAlignment(.center)
                .lineLimit(3).minimumScaleFactor(0.5).padding(.top, 72)
            if let sub = m.sub {
                Text(verbatim: sub).font(ClackFont.inter(36, .semibold)).foregroundStyle(Self.soft).padding(.top, 20)
            }
            Rectangle().fill(Self.ink.opacity(0.15)).frame(height: 2).padding(.top, 88)
            statsRow(m.stats, center: true).padding(.top, 64)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: pieces

    private func kicker(_ text: String) -> some View {
        Text(verbatim: text.uppercased()).font(ClackFont.inter(34, .heavy)).tracking(2).foregroundStyle(Self.soft)
            .lineLimit(1).minimumScaleFactor(0.6)
    }

    private func section(_ text: String) -> some View {
        Text(verbatim: text.uppercased()).font(ClackFont.inter(28, .heavy)).tracking(2).foregroundStyle(Self.soft)
    }

    private func hero(_ value: String, _ unit: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 16) {
            Text(verbatim: value).font(ClackFont.grotesk(190)).monospacedDigit().foregroundStyle(Self.ink)
                .lineLimit(1).minimumScaleFactor(0.4)
            if !unit.isEmpty {
                Text(verbatim: unit).font(ClackFont.grotesk(64)).foregroundStyle(Self.soft)
            }
        }
    }

    @ViewBuilder
    private func medals(_ list: [CardMedal], size: CGFloat) -> some View {
        if !list.isEmpty {
            HStack(alignment: .top, spacing: 16) {
                ForEach(list.prefix(4), id: \.self) { md in
                    VStack(spacing: 10) {
                        Medal(m: md.milestone, size: size, foil: Self.shine)
                        Text(verbatim: md.label).font(ClackFont.inter(22, .bold)).foregroundStyle(Self.ink)
                            .multilineTextAlignment(.center).lineLimit(2).minimumScaleFactor(0.6)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
    }

    private func statsRow(_ stats: [Stat], center: Bool) -> some View {
        HStack(alignment: .top, spacing: 24) {
            ForEach(stats, id: \.self) { stat in
                VStack(alignment: center ? .center : .leading, spacing: 6) {
                    Text(verbatim: stat.value).font(ClackFont.grotesk(60)).monospacedDigit().foregroundStyle(Self.ink)
                        .lineLimit(1).minimumScaleFactor(0.4)
                    Text(verbatim: stat.label.uppercased()).font(ClackFont.inter(24, .bold)).tracking(1).foregroundStyle(Self.soft)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: center ? .center : .leading)
            }
        }
    }
}

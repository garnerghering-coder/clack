//
//  StatsWidgetView.swift
//  ClackDesign
//
//  The Passport tab's rankings as pages: operators, train types, stations, countries. The extension passes the button
//  that flips the page (an App Intent); the gallery passes a plain one.
//

import ClackCore
import SwiftUI

public enum StatsPage: Int, CaseIterable, Sendable {
    case operators, trainTypes, stations, countries

    public var titleKey: String {
        switch self {
        case .operators: "passport.operators"
        case .trainTypes: "passport.trainTypes"
        case .stations: "passport.stationsVisited"
        case .countries: "passport.countries"
        }
    }

    public func rows(_ s: WidgetSnapshot.StatsBits) -> [WidgetSnapshot.Row] {
        switch self {
        case .operators: s.operators
        case .trainTypes: s.trainTypes
        case .stations: s.stations
        case .countries: s.countries
        }
    }

    /// Kept in the widget's own UserDefaults, which needs no App Group.
    public static var current: StatsPage {
        get { StatsPage(rawValue: UserDefaults.standard.integer(forKey: "statsPage")) ?? .operators }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: "statsPage") }
    }
}

public struct StatsWidgetView<NextButton: View>: View {
    var snapshot: WidgetSnapshot
    var date: Date
    var size: WidgetSize
    var page: StatsPage
    var isPlaceholder: Bool
    var nextButton: NextButton
    @Environment(\.colorScheme) private var scheme

    public init(
        snapshot: WidgetSnapshot, date: Date, size: WidgetSize, page: StatsPage, isPlaceholder: Bool = false,
        @ViewBuilder nextButton: () -> NextButton
    ) {
        self.snapshot = snapshot
        self.date = date
        self.size = size
        self.page = page
        self.isPlaceholder = isPlaceholder
        self.nextButton = nextButton()
    }

    private var l10n: L10n { WidgetWords.l10n(snapshot.language) }

    public var body: some View {
        Group {
            if let stats = snapshot.stats {
                ViewThatFits(in: .vertical) {
                    ForEach(rowCounts, id: \.self) { count in content(stats, limit: count) }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            } else {
                EmptyWidget(title: l10n.t("passport.emptyTitle"), hint: l10n.t("widgets.openApp"))
            }
        }
        .environment(l10n)
        .placeholder(isPlaceholder)
    }

    private var rowCounts: [Int] { size == .large ? [8, 7, 6] : [3, 2] }

    /// The button's face: a chevron on the raised surface.
    public static var buttonFace: some View {
        LucideIcon(name: "chevron-right", size: 14).foregroundStyle(Ink.text)
            .frame(width: 32, height: 24)
            .background(Ink.surfaceRaised, in: RoundedRectangle(cornerRadius: Radius.controlSm, style: .continuous))
    }

    private var dots: some View {
        HStack(spacing: 4) {
            ForEach(StatsPage.allCases, id: \.rawValue) { p in
                Circle().fill(p == page ? Ink.accentInk : Ink.text3).frame(width: 5, height: 5)
            }
        }
    }

    private func updated() -> some View {
        UpdatedLine(updatedAt: snapshot.passportUpdatedAt, now: date, l10n: l10n, clock: snapshot.clock)
    }

    private func content(_ stats: WidgetSnapshot.StatsBits, limit: Int) -> some View {
        let rows = Array(page.rows(stats).prefix(limit))
        let top = max(1, rows.map(\.count).max() ?? 1)
        let title = l10n.t(page.titleKey)
        return VStack(alignment: .leading, spacing: 8) {
            // The title, "Updated", the page dots and the button on one line; "Updated" goes under the title when they
            // don't fit.
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 8) {
                    Text(title).clack(.sectionHeader).foregroundStyle(Ink.text).lineLimit(1).fixedSize()
                    Spacer(minLength: 0)
                    updated()
                    dots
                    nextButton
                }
                HStack(spacing: 8) {
                    VStack(alignment: .leading, spacing: 0) {
                        FittingText(title).clack(.sectionHeader).foregroundStyle(Ink.text)
                        updated()
                    }
                    Spacer(minLength: 0)
                    dots
                    nextButton
                }
            }
            ForEach(rows) { row in
                HStack(spacing: 8) {
                    FittingText(row.name).clack(.chip).foregroundStyle(Ink.text).frame(width: 104, alignment: .leading)
                    GeometryReader { p in
                        RoundedRectangle(cornerRadius: Radius.bar)
                            .fill(operatorColor(row.color, scheme: scheme))
                            .frame(width: max(3, p.size.width * Double(row.count) / Double(top)))
                    }
                    .frame(height: 10)
                    Text(String(row.count)).clack(.delay).monospacedDigit().foregroundStyle(Ink.text).lineLimit(1).fixedSize()
                        .frame(minWidth: 28, alignment: .trailing)
                }
            }
            if rows.isEmpty { Text(l10n.t("passport.empty")).clack(.caption).foregroundStyle(Ink.text2) }
            Spacer(minLength: 0)
        }
    }
}

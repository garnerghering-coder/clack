//
//  ExploreFilterSheet.swift
//  Clack
//

import ClackCore
import ClackDesign
import SwiftUI

/// Explore's filters and map settings (owner, 2026-10-28: "organize it, get creative"). A system sheet in sections,
/// each with the control that fits its choice:
/// - what the dot colours mean (one of four)
/// - countries as flag tiles
/// - kinds of train and operators as rows with how many are in view
/// - delay as one of four
/// - your trains and the map layers as switches
///
/// The filters last for the session; the map settings and the colour mode are remembered.
struct ExploreFilterSheet: View {
    @Environment(AppModel.self) private var app
    @Environment(L10n.self) private var l10n
    @Environment(ExploreModel.self) private var model
    @Environment(\.colorScheme) private var scheme
    let onClose: () -> Void

    var body: some View {
        @Bindable var model = model
        let counts = model.countsInView
        SheetFrame(title: l10n.t("liveMap.filters"), onClose: onClose) {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    colorSection
                    section("liveMap.countries") { countryTiles }
                    section("liveMap.kinds") {
                        ForEach(Array(ExploreLogic.products.enumerated()), id: \.element) { i, p in
                            CheckRow(title: l10n.t("products.\(p)"), count: counts.products[p] ?? 0, on: model.filters.products.contains(p), last: i == ExploreLogic.products.count - 1) {
                                toggle(&model.filters.products, p)
                            } leading: {
                                Circle().fill(operatorColor(ExploreLogic.productColors[p] ?? ExploreLogic.otherColor, scheme: scheme)).frame(width: 10, height: 10)
                            }
                        }
                    }
                    section("liveMap.delayTitle") {
                        SegmentedControl(selection: $model.filters.delay, options: ExploreLogic.Delay.allCases.map { ($0, l10n.t("liveMap.delayShort.\($0.rawValue)")) })
                    }
                    section("liveMap.yourTrains") {
                        SwitchRow(title: l10n.t("liveMap.onlyMine"), isOn: $model.filters.onlyMine)
                        SwitchRow(title: l10n.t("liveMap.onlyFollowed"), isOn: $model.filters.onlyFollowed, last: true)
                    }
                    section("liveMap.operators") {
                        let shown = model.operatorsShown
                        if shown.isEmpty { Text(l10n.t("liveMap.noOperatorsInView")).clack(.body).foregroundStyle(Ink.text2) }
                        ForEach(Array(shown.enumerated()), id: \.element) { i, id in
                            CheckRow(title: app.operatorsById[id]?.name ?? id, count: counts.operators[id] ?? 0, on: model.filters.operators.contains(id), last: i == shown.count - 1) {
                                toggle(&model.filters.operators, id)
                            } leading: {
                                OperatorBadge(op: app.operatorsById[id], size: .small)
                            }
                        }
                    }
                    section("liveMap.mapSection") {
                        displaySwitch("liveMap.show.myLocation", \.myLocation)
                        displaySwitch("liveMap.show.trainDots", \.trains)
                        displaySwitch("liveMap.show.trainLabels", \.trainLabels)
                        displaySwitch("liveMap.show.stations", \.stations)
                        displaySwitch("liveMap.show.stationNames", \.stationNames, last: true)
                    }
                    HStack(spacing: 12) {
                        if model.filteredCount > 0 {
                            Button(l10n.t("liveMap.clearFilters")) { model.filters = .init() }.buttonStyle(.clack(wide: true))
                        }
                        Button(l10n.t("common.done"), action: onClose).buttonStyle(.clack(.primary, wide: true))
                    }
                }
                .padding(.bottom, 24)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
    }

    // MARK: colour

    private var colorSection: some View {
        let by = model.controller.display.colorBy
        return section("liveMap.colorBy") {
            SegmentedControl(
                selection: Binding(get: { by }, set: { new in
                    var d = model.controller.display
                    d.colorBy = new
                    model.controller.display = d
                    d.save()
                    model.colorByChanged()
                }),
                options: ExploreLogic.ColorBy.allCases.map { ($0, l10n.t("liveMap.colorBy.\($0.rawValue)")) }
            )
            legend(by)
        }
    }

    /// What the colours mean, under the control: dots with names (the operator mode needs none; the colour is the logo's).
    @ViewBuilder
    private func legend(_ by: ExploreLogic.ColorBy) -> some View {
        let items: [(String, String)] = switch by {
        case .operatorBrand: []
        case .product: ExploreLogic.products.map { (ExploreLogic.productColors[$0] ?? ExploreLogic.otherColor, l10n.t("products.\($0)")) }
        case .delay: [
            (ExploreLogic.delayColors.onTime, l10n.t("liveMap.legend.onTime")), (ExploreLogic.delayColors.slight, "1–15"),
            (ExploreLogic.delayColors.late, "16–30"), (ExploreLogic.delayColors.veryLate, "31+"), (ExploreLogic.delayColors.unknown, l10n.t("liveMap.legend.unknown")),
        ]
        case .country: ["SE", "NO", "DK", "FI"].map { (ExploreLogic.countryColors[$0]!, l10n.t("countries.\($0)")) }
        }
        if items.isEmpty {
            Text(l10n.t("liveMap.colorBy.operatorHint")).clack(.caption).foregroundStyle(Ink.text2)
        } else {
            FlowLayout(spacing: 12, lineSpacing: 8) {
                ForEach(items, id: \.1) { hex, name in
                    HStack(spacing: 4) {
                        Circle().fill(operatorColor(hex, scheme: scheme)).frame(width: 10, height: 10)
                        Text(name).clack(.caption).foregroundStyle(Ink.text2)
                    }
                }
            }
        }
    }

    // MARK: countries

    private var countryTiles: some View {
        HStack(spacing: 8) {
            ForEach(["SE", "NO", "DK", "FI"], id: \.self) { code in
                let on = model.filters.countries.contains(code)
                Button { toggleCountry(code) } label: {
                    VStack(spacing: 8) {
                        Flag(country: code, size: 32, decorative: true)
                        Text(l10n.t("countries.\(code)")).clack(.caption).foregroundStyle(Ink.text).lineLimit(1).minimumScaleFactor(0.8)
                    }
                    .frame(maxWidth: .infinity).padding(.vertical, 12)
                    .background(Ink.surfaceRaised, in: RoundedRectangle(cornerRadius: Radius.controlSm, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: Radius.controlSm, style: .continuous).strokeBorder(on ? Ink.accent : Ink.hairline, lineWidth: on ? 2 : 1))
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(l10n.t("countries.\(code)"))
                .accessibilityAddTraits(on ? .isSelected : [])
            }
        }
    }

    private func toggleCountry(_ code: String) {
        @Bindable var model = model
        toggle(&model.filters.countries, code)
    }

    // MARK: parts

    private func section<Content: View>(_ key: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(l10n.t(key)).clack(.sectionHeader).foregroundStyle(Ink.text2)
            content()
        }
    }

    private func displaySwitch(_ key: String, _ path: WritableKeyPath<MapDisplay, Bool>, last: Bool = false) -> some View {
        SwitchRow(title: l10n.t(key), isOn: Binding(get: { model.controller.display[keyPath: path] }, set: { on in
            var d = model.controller.display
            d[keyPath: path] = on
            model.controller.display = d
            d.save()
            if path == \.myLocation && on { model.controller.showUserDot() }
        }), last: last)
    }

    private func toggle(_ set: inout Set<String>, _ value: String) {
        if set.contains(value) { set.remove(value) } else { set.insert(value) }
    }
}

/// A row that switches a choice on and off: what it is, how many are in view, a check when chosen.
private struct CheckRow<Leading: View>: View {
    let title: String
    let count: Int
    let on: Bool
    var last = false
    let action: () -> Void
    @ViewBuilder var leading: Leading

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                leading
                Text(title).clack(.body).foregroundStyle(Ink.text)
                Spacer(minLength: 8)
                Text(String(count)).clack(.caption).monospacedDigit().foregroundStyle(Ink.text3)
                LucideIcon(name: "check", size: 18).foregroundStyle(Ink.accentInk).opacity(on ? 1 : 0)
            }
            .frame(minHeight: 44)
            .overlay(alignment: .bottom) { if !last { Rectangle().fill(Ink.hairline).frame(height: 1) } }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(on ? .isSelected : [])
    }
}

/// A row with a switch (Settings' look).
private struct SwitchRow: View {
    let title: String
    @Binding var isOn: Bool
    var last = false

    var body: some View {
        Toggle(isOn: $isOn) { Text(title).clack(.body).foregroundStyle(Ink.text) }
            .tint(Ink.accent)
            .frame(minHeight: 44)
            .overlay(alignment: .bottom) { if !last { Rectangle().fill(Ink.hairline).frame(height: 1) } }
    }
}

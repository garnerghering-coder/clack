//
//  ExploreFilterSheet.swift
//  Clack
//

import ClackCore
import ClackDesign
import SwiftUI

/// Explore's filters and map settings as a system `Form` (owner, 2026-10-28: Apple's own controls, "no hand-made
/// buttons"): a segmented picker for what the dot colours mean, toggles for countries (with their flags), kinds of
/// train and operators (each with how many are in view), a segmented picker for delay, and switches for your trains
/// and the map's layers. The filters last for the session; the map settings and the colour mode are remembered.
struct ExploreFilterSheet: View {
    @Environment(AppModel.self) private var app
    @Environment(L10n.self) private var l10n
    @Environment(ExploreModel.self) private var model
    @Environment(\.colorScheme) private var scheme
    let onClose: () -> Void

    var body: some View {
        @Bindable var model = model
        let counts = model.countsInView
        NavigationStack {
            Form {
                Section {
                    SegmentedControl(
                        selection: Binding(get: { model.controller.display.colorBy }, set: { setColorBy($0) }),
                        options: ExploreLogic.ColorBy.allCases.map { ($0, l10n.t("liveMap.colorBy.\($0.rawValue)")) }
                    )
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                    legend(model.controller.display.colorBy)
                } header: {
                    Text(l10n.t("liveMap.colorBy"))
                }
                Section(l10n.t("liveMap.countries")) {
                    ForEach(["SE", "NO", "DK", "FI"], id: \.self) { code in
                        Toggle(isOn: member($model.filters.countries, code)) {
                            Label { Text(l10n.t("countries.\(code)")) } icon: { Flag(country: code, size: 24, decorative: true) }
                        }
                    }
                }
                Section(l10n.t("liveMap.kinds")) {
                    ForEach(ExploreLogic.products, id: \.self) { p in
                        Toggle(isOn: member($model.filters.products, p)) {
                            countedLabel(l10n.t("products.\(p)"), count: counts.products[p] ?? 0) {
                                Circle().fill(operatorColor(ExploreLogic.productColors[p] ?? ExploreLogic.otherColor, scheme: scheme)).frame(width: 12, height: 12)
                            }
                        }
                    }
                }
                Section(l10n.t("liveMap.delayTitle")) {
                    SegmentedControl(selection: $model.filters.delay, options: ExploreLogic.Delay.allCases.map { ($0, l10n.t("liveMap.delayShort.\($0.rawValue)")) })
                        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                }
                Section(l10n.t("liveMap.yourTrains")) {
                    Toggle(l10n.t("liveMap.onlyMine"), isOn: $model.filters.onlyMine)
                    Toggle(l10n.t("liveMap.onlyFollowed"), isOn: $model.filters.onlyFollowed)
                }
                Section(l10n.t("liveMap.operators")) {
                    let shown = model.operatorsShown
                    if shown.isEmpty { Text(l10n.t("liveMap.noOperatorsInView")).foregroundStyle(.secondary) }
                    ForEach(shown, id: \.self) { id in
                        Toggle(isOn: member($model.filters.operators, id)) {
                            countedLabel(app.operatorsById[id]?.name ?? id, count: counts.operators[id] ?? 0) {
                                OperatorBadge(op: app.operatorsById[id], size: .small)
                            }
                        }
                    }
                }
                Section(l10n.t("liveMap.mapSection")) {
                    displayToggle("liveMap.show.myLocation", \.myLocation)
                    displayToggle("liveMap.show.trainDots", \.trains)
                    displayToggle("liveMap.show.trainLabels", \.trainLabels)
                    displayToggle("liveMap.show.stations", \.stations)
                    displayToggle("liveMap.show.stationNames", \.stationNames)
                }
            }
            .tint(Ink.accent)
            .navigationTitle(l10n.t("liveMap.filters"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if model.filteredCount > 0 {
                    ToolbarItem(placement: .topBarLeading) { Button(l10n.t("liveMap.clearFilters")) { model.filters = .init() } }
                }
                ToolbarItem(placement: .confirmationAction) { Button(l10n.t("common.done"), action: onClose) }
            }
        }
    }

    /// A row's label with a leading mark and the count of trains in view.
    private func countedLabel<Icon: View>(_ title: String, count: Int, @ViewBuilder icon: () -> Icon) -> some View {
        HStack(spacing: 12) {
            icon()
            Text(title)
            Spacer(minLength: 8)
            Text(String(count)).foregroundStyle(.secondary).monospacedDigit()
        }
    }

    /// What the colours mean, under the picker; the operator mode needs no legend (the colour is the logo's).
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
            Text(l10n.t("liveMap.colorBy.operatorHint")).font(.footnote).foregroundStyle(.secondary)
        } else {
            FlowLayout(spacing: 12, lineSpacing: 8) {
                ForEach(items, id: \.1) { hex, name in
                    HStack(spacing: 4) {
                        Circle().fill(operatorColor(hex, scheme: scheme)).frame(width: 10, height: 10)
                        Text(name).font(.footnote).foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    private func setColorBy(_ new: ExploreLogic.ColorBy) {
        var d = model.controller.display
        d.colorBy = new
        model.controller.display = d
        d.save()
        model.colorByChanged()
    }

    /// A toggle over membership in a set of filters.
    private func member(_ set: Binding<Set<String>>, _ value: String) -> Binding<Bool> {
        Binding(get: { set.wrappedValue.contains(value) }, set: { on in if on { set.wrappedValue.insert(value) } else { set.wrappedValue.remove(value) } })
    }

    private func displayToggle(_ key: String, _ path: WritableKeyPath<MapDisplay, Bool>) -> some View {
        Toggle(l10n.t(key), isOn: Binding(get: { model.controller.display[keyPath: path] }, set: { on in
            var d = model.controller.display
            d[keyPath: path] = on
            model.controller.display = d
            d.save()
            if path == \.myLocation && on { model.controller.showUserDot() }
        }))
    }
}

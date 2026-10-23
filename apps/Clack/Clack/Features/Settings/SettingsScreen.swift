//
//  SettingsScreen.swift
//  Clack
//

import SwiftUI

/// The gear in a tab's header: opens Settings.
struct SettingsLink: View {
    @Environment(L10n.self) private var l10n

    var body: some View {
        NavigationLink(value: AppRoute.settings) {
            LucideIcon(name: "settings", size: 20)
                .foregroundStyle(Ink.text)
                .frame(width: 44, height: 44)
                .background(Ink.surfaceRaised, in: Circle())
                .overlay(Circle().strokeBorder(Ink.hairline, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(l10n.t("nav.settings"))
    }
}

/// A settings row: the label, then its control; a hairline underneath except on the last row of a card (`.row`).
private struct SettingsRow<Control: View>: View {
    let label: String
    var last = false
    @ViewBuilder var control: Control

    var body: some View {
        HStack(spacing: 12) {
            Text(label).clack(.settingsRow).foregroundStyle(Ink.text)
            Spacer(minLength: 0)
            control
        }
        .frame(minHeight: 52)
        .overlay(alignment: .bottom) { if !last { Rectangle().fill(Ink.hairline).frame(height: 1) } }
    }
}

/// A select: the current value in a small raised box (`.row select`); tapping opens the choices.
private struct ChoiceMenu<Value: Hashable>: View {
    let label: String
    let options: [(value: Value, title: String)]
    let selection: Value
    let onChange: (Value) -> Void

    var body: some View {
        Menu {
            Picker(label, selection: Binding(get: { selection }, set: onChange)) {
                ForEach(Array(options.enumerated()), id: \.offset) { _, option in Text(option.title).tag(option.value) }
            }
        } label: {
            HStack(spacing: 6) {
                Text(options.first { $0.value == selection }?.title ?? "").lineLimit(1)
                LucideIcon(name: "chevron-down", size: 14).foregroundStyle(Ink.text2)
            }
            .font(ClackFont.inter(15)).foregroundStyle(Ink.text)
            .padding(.vertical, 7).padding(.horizontal, 10)
            .background(Ink.surfaceRaised, in: RoundedRectangle(cornerRadius: Radius.controlSm, style: .continuous))
            .hairlineBorder(radius: Radius.controlSm)
        }
        .accessibilityLabel(label)
    }
}

/// Settings (SettingsPage.tsx): appearance, your name, language, units and the rest, all saved to the server as they change.
struct SettingsScreen: View {
    @Environment(AppModel.self) private var app
    @Environment(L10n.self) private var l10n

    /// Saves a change (shown at once; undone if the server refuses it).
    private func change(_ patch: SettingsPatch) {
        Task { await app.update(patch) }
    }

    var body: some View {
        let s = app.settings
        Page {
            BackLink()
            PageHeader(title: l10n.t("settings.title"))
            if app.saveFailed { Banner(kind: .error) { Text(l10n.t("settings.saveError")) } }
            Card {
                HStack(spacing: 12) {
                    Text(l10n.t("settings.theme")).clack(.settingsRow).foregroundStyle(Ink.text)
                    Spacer(minLength: 0)
                    SegmentedControl(
                        selection: Binding(get: { s.theme }, set: { value in change(SettingsPatch(theme: value)) }),
                        options: ThemeSetting.knownCases.map { ($0, l10n.t("settings.themes.\($0.rawValue)")) }, small: true
                    )
                }
                .frame(minHeight: 52)
            }
            Card {
                NameRow()
                SettingsRow(label: l10n.t("settings.language")) {
                    ChoiceMenu(label: l10n.t("settings.language"), options: Language.knownCases.map { ($0, l10n.t("settings.languages.\($0.rawValue)")) }, selection: s.language) { value in
                        change(SettingsPatch(language: value))
                    }
                }
                SettingsRow(label: l10n.t("settings.distanceUnit")) {
                    ChoiceMenu(label: l10n.t("settings.distanceUnit"), options: DistanceUnit.knownCases.map { ($0, l10n.t("settings.units.\($0.rawValue)")) }, selection: s.distanceUnit) { value in
                        change(SettingsPatch(distanceUnit: value))
                    }
                }
                SettingsRow(label: l10n.t("settings.clock")) {
                    ChoiceMenu(label: l10n.t("settings.clock"), options: ClockFormat.knownCases.map { ($0, l10n.t("settings.clocks.\($0.rawValue)")) }, selection: s.clock) { value in
                        change(SettingsPatch(clock: value))
                    }
                }
                SettingsRow(label: l10n.t("settings.co2Comparison"), last: true) {
                    // What the app offers; an older setting still shows as itself.
                    let choices = Settings.co2Choices.contains(s.co2Comparison) ? Settings.co2Choices : [s.co2Comparison] + Settings.co2Choices
                    ChoiceMenu(label: l10n.t("settings.co2Comparison"), options: choices.map { ($0, l10n.t("settings.co2.\($0.rawValue)")) }, selection: s.co2Comparison) { value in
                        change(SettingsPatch(co2Comparison: value))
                    }
                }
            }
            Card {
                SettingsToggle(label: l10n.t("settings.includeCommuter"), isOn: s.includeCommuter) { value in change(SettingsPatch(includeCommuter: value)) }
                SettingsToggle(label: l10n.t("settings.showRailNetwork"), isOn: s.showRailNetwork, last: true) { value in change(SettingsPatch(showRailNetwork: value)) }
            }
            Card {
                Text(l10n.t("settings.changing")).clack(.sectionHeader).foregroundStyle(Ink.text2)
                SettingsRow(label: l10n.t("settings.walkPace")) {
                    ChoiceMenu(label: l10n.t("settings.walkPace"), options: WalkPace.knownCases.map { ($0, l10n.t("settings.paces.\($0.rawValue)")) }, selection: s.walkPace) { value in
                        change(SettingsPatch(walkPace: value))
                    }
                }
                SettingsToggle(label: l10n.t("settings.stepFree"), isOn: s.stepFree) { value in change(SettingsPatch(stepFree: value)) }
                SettingsToggle(label: l10n.t("settings.heavyLuggage"), isOn: s.heavyLuggage, last: true) { value in change(SettingsPatch(heavyLuggage: value)) }
                Text(l10n.t("settings.changingNote")).clack(.caption).foregroundStyle(Ink.text2)
            }
            Card {
                LinkRow(label: l10n.t("settings.about"), route: .about, last: true)
            }
            Card {
                Text(l10n.t("settings.yourData")).clack(.sectionHeader).foregroundStyle(Ink.text2)
                LinkRow(label: l10n.t("settings.privacy"), route: .privacy)
                DeleteMyDataRow()
            }
            #if DEBUG
            NavigationLink("Design") { DesignGalleryView().toolbar(.hidden, for: .navigationBar) }
                .buttonStyle(.clack(wide: true))
            #endif
        }
    }
}

private struct SettingsToggle: View {
    let label: String
    let isOn: Bool
    var last = false
    let onChange: (Bool) -> Void

    var body: some View {
        SettingsRow(label: label, last: last) {
            Toggle("", isOn: Binding(get: { isOn }, set: onChange)).labelsHidden().tint(Ink.accent)
        }
        .accessibilityElement(children: .combine)
    }
}

private struct LinkRow: View {
    let label: String
    let route: AppRoute
    var last = false

    var body: some View {
        NavigationLink(value: route) {
            SettingsRow(label: label, last: last) {
                LucideIcon(name: "chevron-right", size: 18).foregroundStyle(Ink.text3)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

/// Your name, saved when you finish typing.
private struct NameRow: View {
    @Environment(AppModel.self) private var app
    @Environment(L10n.self) private var l10n
    @State private var value = ""
    @FocusState private var focused: Bool

    var body: some View {
        SettingsRow(label: l10n.t("settings.displayName")) {
            TextField("", text: $value, prompt: Text(l10n.t("settings.displayNamePlaceholder")).foregroundStyle(Ink.text3))
                .focused($focused)
                .multilineTextAlignment(.trailing)
                .font(ClackFont.inter(15)).foregroundStyle(Ink.text)
                .padding(.vertical, 7).padding(.horizontal, 10)
                .frame(maxWidth: 200)
                .background(Ink.surfaceRaised, in: RoundedRectangle(cornerRadius: Radius.controlSm, style: .continuous))
                .hairlineBorder(radius: Radius.controlSm)
                .onChange(of: value) { _, new in if new.count > Settings.displayNameMaxLength { value = String(new.prefix(Settings.displayNameMaxLength)) } }
                .onChange(of: focused) { _, isFocused in
                    if !isFocused, value != app.settings.displayName { Task { await app.update(SettingsPatch(displayName: value)) } }
                }
                .accessibilityLabel(l10n.t("settings.displayName"))
        }
        .onAppear { value = app.settings.displayName }
        .onChange(of: app.settings.displayName) { _, new in if !focused { value = new } }
    }
}

/// App Review 5.1.1(v): whatever we keep for this phone can be deleted from inside the app, at once.
private struct DeleteMyDataRow: View {
    enum Phase { case idle, busy, done }

    @Environment(AppModel.self) private var app
    @Environment(L10n.self) private var l10n
    @State private var phase = Phase.idle
    @State private var confirming = false

    var body: some View {
        Group {
            if phase == .done {
                Text(l10n.t("settings.deleted")).clack(.caption).foregroundStyle(Ink.text2)
            } else {
                Button(l10n.t("settings.deleteData")) { confirming = true }
                    .buttonStyle(.clack(.danger))
                    .disabled(phase == .busy)
                    .padding(.vertical, 8)
            }
        }
        .confirmationDialog(l10n.t("settings.deleteConfirm"), isPresented: $confirming, titleVisibility: .visible) {
            Button(l10n.t("settings.deleteData"), role: .destructive) {
                phase = .busy
                Task { phase = await app.deleteMyData() ? .done : .idle }
            }
            Button(l10n.t("common.close"), role: .cancel) {}
        }
    }
}

/// Sources and methodology (AboutPage.tsx).
struct AboutScreen: View {
    @Environment(L10n.self) private var l10n

    private static let sources = ["trafikverket", "gtfsSweden3", "gtfsSverige2", "entur", "osm", "stationMaps", "onboard"]

    var body: some View {
        Page {
            BackLink(label: l10n.t("settings.title"))
            PageHeader(title: l10n.t("about.title"))
            Card(spacing: 12) {
                Text(l10n.t("about.intro")).clack(.body).foregroundStyle(Ink.text)
                Text(l10n.t("about.sourcesTitle")).clack(.sectionHeader).foregroundStyle(Ink.text2)
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(Self.sources, id: \.self) { source in
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            Text("•")
                            Text(l10n.t("about.sources.\(source)"))
                        }
                        .clack(.body).foregroundStyle(Ink.text2)
                    }
                }
                Text(l10n.t("about.delaysTitle")).clack(.sectionHeader).foregroundStyle(Ink.text2)
                Text(l10n.t("about.delaysBody", ["max": String(Delay.onTimeMaxDelayMin)])).clack(.body).foregroundStyle(Ink.text)
                Text(l10n.t("about.co2Title")).clack(.sectionHeader).foregroundStyle(Ink.text2)
                Text(l10n.t("about.co2Body")).clack(.body).foregroundStyle(Ink.text)
            }
        }
    }
}

/// The privacy policy (App Review 5.1.1(i): reachable in the app). Plain statements of what is true of the code
/// (PrivacyPage.tsx); keep it in step when data handling changes (docs/APP_STORE.md).
struct PrivacyScreen: View {
    @Environment(L10n.self) private var l10n

    private static let parts = ["stored", "phone", "location", "notCollected", "sharing", "deletion"]

    var body: some View {
        Page {
            BackLink(label: l10n.t("settings.title"))
            PageHeader(title: l10n.t("privacy.title"))
            Card(spacing: 12) {
                Text(l10n.t("privacy.intro")).clack(.body).foregroundStyle(Ink.text)
                ForEach(Self.parts, id: \.self) { part in
                    VStack(alignment: .leading, spacing: 12) {
                        Text(l10n.t("privacy.\(part)Title")).clack(.sectionHeader).foregroundStyle(Ink.text2)
                        Text(l10n.t("privacy.\(part)Body")).clack(.body).foregroundStyle(Ink.text)
                    }
                }
                if let email = Config.supportEmail {
                    Text(l10n.t("privacy.contactTitle")).clack(.sectionHeader).foregroundStyle(Ink.text2)
                    (Text(l10n.t("privacy.contactBody") + " ") + Text(.init("[\(email)](mailto:\(email))"))).clack(.body).foregroundStyle(Ink.text)
                }
                Text(l10n.t("privacy.updated", ["date": "2026-10-23"])).clack(.caption).foregroundStyle(Ink.text2)
            }
        }
    }
}

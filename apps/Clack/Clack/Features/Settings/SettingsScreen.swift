//
//  SettingsScreen.swift
//  Clack
//

import ClackCore
import ClackDesign
import SwiftUI

/// The gear in a tab's header: opens Settings.
struct SettingsLink: View {
    @Environment(L10n.self) private var l10n

    var body: some View {
        IconLink(icon: "settings", label: l10n.t("nav.settings"), value: AppRoute.settings)
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
    /// What the button says when `selection` is none of the options (a setting that has not been chosen yet).
    var unsetTitle = ""
    let onChange: (Value) -> Void

    var body: some View {
        Menu {
            Picker(label, selection: Binding(get: { selection }, set: onChange)) {
                ForEach(Array(options.enumerated()), id: \.offset) { _, option in Text(option.title).tag(option.value) }
            }
        } label: {
            HStack(spacing: 8) {
                Text(options.first { $0.value == selection }?.title ?? unsetTitle).lineLimit(1)
                LucideIcon(name: "chevron-down", size: 14).foregroundStyle(Ink.text2)
            }
            .clack(.body).foregroundStyle(Ink.text)
            .padding(.vertical, 8).padding(.horizontal, 12)
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
            if app.saveFailed { Banner(kind: .error) { Text(l10n.t("settings.saveError")) }.countsError("settings.save") }
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
                // Unset until the phone's region or the first trip decides (the server's rule); picking one makes it yours.
                SettingsRow(label: l10n.t("settings.homeCountry")) {
                    ChoiceMenu(
                        label: l10n.t("settings.homeCountry"),
                        options: HomeCountry.knownCases.map { (Optional($0), l10n.t("countries.\($0.rawValue)")) },
                        selection: s.homeCountry, unsetTitle: l10n.t("settings.homeCountryAuto")
                    ) { value in
                        if let value { change(SettingsPatch(homeCountry: value)) }
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
                InfoNote(l10n.t("settings.changingNote"), more: l10n.t("settings.changingNoteMore"))
            }
            AlertsCard(change: change)
            OfflineMapsCard()
            Card {
                LinkRow(label: l10n.t("settings.about"), route: .about)
                ReportBugRow()
            }
            UsageCard()
            Card {
                Text(l10n.t("settings.yourData")).clack(.sectionHeader).foregroundStyle(Ink.text2)
                LinkRow(label: l10n.t("settings.privacy"), route: .privacy)
                ExportDataRow()
                DeleteMyDataRow()
                StartOverRow()
            }
            VersionFooter()
            #if DEBUG
            NavigationLink("Test alerts", value: AppRoute.testAlerts)
                .buttonStyle(.clack(wide: true))
            NavigationLink("Design") { DesignGalleryView().toolbar(.hidden, for: .navigationBar) }
                .buttonStyle(.clack(wide: true))
            #endif
        }
        .screenTitle(l10n.t("settings.title")).countsScreen("settings")
    }
}

/// The maps saved for when there is no signal (owner, 2026-10-24).
private struct OfflineMapsCard: View {
    @Environment(L10n.self) private var l10n
    @State private var count = OfflineMaps.savedCount

    var body: some View {
        Card {
            Text(l10n.t("settings.offlineMaps")).clack(.sectionHeader).foregroundStyle(Ink.text2)
            Text(l10n.t("settings.offlineMapsCount", count: count, ["count": String(count)])).clack(.body).foregroundStyle(Ink.text)
            InfoNote(l10n.t("settings.offlineMapsNote"), more: l10n.t("settings.offlineMapsNoteMore"))
            if count > 0 {
                Button(l10n.t("settings.offlineMapsClear")) {
                    Task {
                        await OfflineMaps.clear()
                        count = OfflineMaps.savedCount
                    }
                }
                .buttonStyle(ClackButtonStyle(small: true))
            }
        }
        .task { count = OfflineMaps.savedCount }
    }
}

/// Alerts (owner, 2026-10-23): one switch (which asks iOS for permission), when the reminder comes, and what to be told.
private struct AlertsCard: View {
    @Environment(AppModel.self) private var app
    @Environment(L10n.self) private var l10n
    @Environment(\.openURL) private var openURL
    let change: (SettingsPatch) -> Void
    private var manager: NotificationManager { app.notifications }

    var body: some View {
        let s = app.settings
        Card {
            Text(l10n.t("settings.alerts.title")).clack(.sectionHeader).foregroundStyle(Ink.text2)
            SettingsToggle(label: l10n.t("settings.alerts.master"), isOn: s.notify, last: !s.notify) { value in
                if value {
                    Task {
                        // The switch turns on only if iOS says yes.
                        if await manager.requestPermission() { change(SettingsPatch(notify: true)) }
                    }
                } else {
                    change(SettingsPatch(notify: false))
                    Task { await manager.forget(app.client) }
                }
            }
            if s.notify {
                SettingsRow(label: l10n.t("settings.alerts.lead")) {
                    ChoiceMenu(label: l10n.t("settings.alerts.lead"), options: Settings.leadChoices.map { ($0, l10n.t("settings.alerts.leads.\($0)")) }, selection: s.notifyLeadMin) { value in
                        change(SettingsPatch(notifyLeadMin: value))
                    }
                }
                SettingsToggle(label: l10n.t("settings.alerts.platform"), isOn: s.notifyPlatform) { change(SettingsPatch(notifyPlatform: $0)) }
                SettingsToggle(label: l10n.t("settings.alerts.delay"), isOn: s.notifyDelay) { change(SettingsPatch(notifyDelay: $0)) }
                SettingsToggle(label: l10n.t("settings.alerts.cancel"), isOn: s.notifyCancel) { change(SettingsPatch(notifyCancel: $0)) }
                SettingsToggle(label: l10n.t("settings.alerts.change"), isOn: s.notifyChange) { change(SettingsPatch(notifyChange: $0)) }
                SettingsToggle(label: l10n.t("settings.alerts.getOff"), isOn: s.notifyGetOff) { change(SettingsPatch(notifyGetOff: $0)) }
                SettingsToggle(label: l10n.t("settings.alerts.arrival"), isOn: s.notifyArrival, last: true) { change(SettingsPatch(notifyArrival: $0)) }
            }
            InfoNote(l10n.t("settings.alerts.note"), more: l10n.t("settings.alerts.noteMore"))
            if manager.denied {
                Text(l10n.t("settings.alerts.denied")).clack(.caption).foregroundStyle(Ink.text2)
                Button(l10n.t("settings.alerts.openSettings")) {
                    if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                }
                .buttonStyle(ClackButtonStyle(small: true))
            }
        }
        .task { await manager.refresh() }
    }
}

/// Which version of the app this is, and which commit the server runs, so it is easy to tell an update has arrived.
private struct VersionFooter: View {
    @Environment(AppModel.self) private var app
    @Environment(L10n.self) private var l10n
    @State private var server: String?

    private var version: String {
        l10n.t("settings.version", [
            "version": Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?",
            "build": Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "?",
        ])
    }

    var body: some View {
        VStack(spacing: 2) {
            Text(version).clack(.caption).foregroundStyle(Ink.text3)
            if let server { Text(l10n.t("settings.serverVersion", ["version": server])).clack(.caption).foregroundStyle(Ink.text3) }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 4)
        .task { server = try? await app.client.serverVersion() }
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

/// Usage data (owner, 2026-10-25): anonymous daily counts and Apple's crash reports to Clack's own server, on unless
/// turned off here. What's counted is said in plain words under the switch.
private struct UsageCard: View {
    @Environment(L10n.self) private var l10n
    @State private var on = Usage.shared.enabled

    var body: some View {
        Card {
            Text(l10n.t("settings.usage.title")).clack(.sectionHeader).foregroundStyle(Ink.text2)
            SettingsToggle(label: l10n.t("settings.usage.share"), isOn: on, last: true) { value in
                on = value
                Usage.shared.enabled = value
            }
            Text(l10n.t("settings.usage.note")).clack(.caption).foregroundStyle(Ink.text2).fixedSize(horizontal: false, vertical: true)
        }
    }
}

/// "Report a bug": an email to Clack with the app version, build, iOS and the last error filled in; nothing else is
/// attached unless they add it.
private struct ReportBugRow: View {
    @Environment(L10n.self) private var l10n
    @Environment(\.openURL) private var openURL

    var body: some View {
        Button {
            if let url = Self.mail(l10n) { openURL(url) }
        } label: {
            SettingsRow(label: l10n.t("settings.reportBug"), last: true) {
                LucideIcon(name: "external-link", size: 18).foregroundStyle(Ink.text3)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    static func mail(_ l10n: L10n) -> URL? {
        guard let email = Config.supportEmail else { return nil }
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"
        let lastError = (UserDefaults.standard.dictionary(forKey: "clack.usage.lastError")?["name"] as? String) ?? "–"
        let body = l10n.t("settings.reportBugBody", [
            "version": version, "build": Usage.build, "ios": UIDevice.current.systemVersion, "error": lastError,
        ])
        var c = URLComponents()
        c.scheme = "mailto"
        c.path = email
        c.queryItems = [URLQueryItem(name: "subject", value: l10n.t("settings.reportBugSubject")), URLQueryItem(name: "body", value: body)]
        return c.url
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
                .clack(.body).foregroundStyle(Ink.text)
                .padding(.vertical, 8).padding(.horizontal, 12)
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

/// "Export my data" (DESIGN §11): everything the server keeps for this phone, as a JSON file, shared from the phone.
/// Fetched when you ask; then the share sheet sends it where you like.
private struct ExportDataRow: View {
    enum Phase: Equatable { case idle, busy, ready(URL), failed }

    @Environment(AppModel.self) private var app
    @Environment(L10n.self) private var l10n
    @State private var phase = Phase.idle

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            switch phase {
            case .ready(let file):
                ShareLink(item: file) {
                    HStack(spacing: 8) {
                        LucideIcon(name: "share-2", size: 16)
                        Text(l10n.t("settings.exportShare"))
                    }
                }
                .buttonStyle(.clack(.primary))
                Text(file.lastPathComponent).clack(.caption).foregroundStyle(Ink.text2)
            default:
                Button {
                    Task { await export() }
                } label: {
                    HStack(spacing: 8) {
                        LucideIcon(name: "download", size: 16)
                        Text(l10n.t("settings.export"))
                    }
                }
                .buttonStyle(.clack())
                .disabled(phase == .busy)
                if phase == .failed { Text(l10n.t("settings.exportFailed")).clack(.caption).foregroundStyle(Ink.veryLateInk) }
            }
        }
        .padding(.vertical, 8)
    }

    private func export() async {
        phase = .busy
        do {
            let data = try await app.client.exportData()
            let file = FileManager.default.temporaryDirectory.appendingPathComponent(DataExport.fileName(now: .now))
            try data.write(to: file, options: [.atomic, .completeFileProtection])
            phase = .ready(file)
        } catch {
            phase = .failed
        }
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
        .sensoryFeedback(.warning, trigger: phase == .done)
        .confirmationDialog(l10n.t("settings.deleteConfirm"), isPresented: $confirming, titleVisibility: .visible) {
            Button(l10n.t("settings.deleteData"), role: .destructive) {
                phase = .busy
                Task { phase = await app.deleteMyData() ? .done : .idle }
            }
            Button(l10n.t("common.close"), role: .cancel) {}
        }
    }
}

/// Erases everything and starts the app again as if it had never been opened (owner, 2026-10-25).
private struct StartOverRow: View {
    @Environment(AppModel.self) private var app
    @Environment(L10n.self) private var l10n
    @State private var busy = false
    @State private var failed = false
    @State private var confirming = false

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Button(l10n.t("settings.startOver")) { confirming = true }
                .buttonStyle(.clack(.danger))
                .disabled(busy)
                .padding(.vertical, 8)
            if failed { Text(l10n.t("settings.startOverFailed")).clack(.caption).foregroundStyle(Ink.text2) }
        }
        .sensoryFeedback(.warning, trigger: busy)
        .confirmationDialog(l10n.t("settings.startOverConfirm"), isPresented: $confirming, titleVisibility: .visible) {
            Button(l10n.t("settings.startOver"), role: .destructive) {
                busy = true
                failed = false
                Task {
                    failed = await !app.startOver()
                    busy = false
                }
            }
            Button(l10n.t("common.close"), role: .cancel) {}
        }
    }
}

/// Sources and methodology (AboutPage.tsx).
struct AboutScreen: View {
    @Environment(L10n.self) private var l10n

    private static let sources = ["trafikverket", "gtfsSweden3", "gtfsSverige2", "entur", "digitraffic", "rejseplanen", "osm", "stationMaps", "onboard"]

    var body: some View {
        Page {
            Card(spacing: 12) {
                Text(l10n.t("about.intro")).clack(.body).foregroundStyle(Ink.text)
                Text(l10n.t("about.sourcesTitle")).clack(.sectionHeader).foregroundStyle(Ink.text2)
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(Self.sources, id: \.self) { source in
                        Text(l10n.t("about.sources.\(source)")).clack(.body).foregroundStyle(Ink.text2)
                    }
                }
                Text(l10n.t("about.delaysTitle")).clack(.sectionHeader).foregroundStyle(Ink.text2)
                Text(l10n.t("about.delaysBody", ["max": String(Delay.onTimeMaxDelayMin)])).clack(.body).foregroundStyle(Ink.text)
                Text(l10n.t("about.co2Title")).clack(.sectionHeader).foregroundStyle(Ink.text2)
                Text(l10n.t("about.co2Body")).clack(.body).foregroundStyle(Ink.text)
            }
        }
        .screenTitle(l10n.t("about.title"))
    }
}

/// The privacy policy (App Review 5.1.1(i): reachable in the app). Plain statements of what is true of the code
/// (PrivacyPage.tsx); keep it in step when data handling changes (docs/APP_STORE.md).
struct PrivacyScreen: View {
    @Environment(L10n.self) private var l10n

    private static let parts = ["stored", "phone", "alerts", "location", "notCollected", "sharing", "deletion", "usage"]

    var body: some View {
        Page {
            Card(spacing: 12) {
                Text(l10n.t("privacy.intro")).clack(.body).foregroundStyle(Ink.text)
                ForEach(Self.parts, id: \.self) { part in
                    VStack(alignment: .leading, spacing: 12) {
                        Text(l10n.t("privacy.\(part)Title")).clack(.sectionHeader).foregroundStyle(Ink.text2)
                        Text(l10n.t("privacy.\(part)Body")).clack(.body).foregroundStyle(Ink.text)
                        if part == "stored" { Text(l10n.t("privacy.idSync")).clack(.body).foregroundStyle(Ink.text) }
                    }
                }
                if let email = Config.supportEmail {
                    Text(l10n.t("privacy.contactTitle")).clack(.sectionHeader).foregroundStyle(Ink.text2)
                    (Text(l10n.t("privacy.contactBody") + " ") + Text(.init("[\(email)](mailto:\(email))"))).clack(.body).foregroundStyle(Ink.text)
                }
                Text(l10n.t("privacy.updated", ["date": "2026-10-26"])).clack(.caption).foregroundStyle(Ink.text2)
            }
        }
        .screenTitle(l10n.t("privacy.title"))
    }
}

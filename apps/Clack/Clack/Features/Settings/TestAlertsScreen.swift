//
//  TestAlertsScreen.swift
//  Clack
//

#if DEBUG
import ActivityKit
import ClackCore
import ClackDesign
import SwiftUI
import UserNotifications

/// Debug only: fire each alert the server sends, and run the trip card (Lock Screen and Dynamic Island) through its
/// states, from the phone itself. No Apple push or server needed: these are local notifications and a local Live
/// Activity, with the same wording the server uses (apps/server/src/push/text.ts; keep the two in step).
@MainActor
@Observable
final class TestAlertsModel {
    var delay: Double = 5
    var message: String?
    private(set) var activity: Activity<TripActivityAttributes>?

    // MARK: sample trip

    private let from = "Nässjö C"
    private let to = "Jönköping C"
    private var swedish = false

    private func t(_ en: String, _ sv: String) -> String { swedish ? sv : en }
    private func clock(_ minutes: Double) -> String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f.string(from: Date(timeIntervalSinceNow: minutes * 60))
    }

    struct Sample: Identifiable {
        let id: String
        let title: String
        let body: String
        var timeSensitive = false
    }

    func samples(language: Language) -> [Sample] {
        swedish = language == .sv
        let route = "\(from) → \(to)"
        return [
            Sample(id: "reminder", title: route, body: t("Leaves \(clock(60)) from platform 5.", "Avgår \(clock(60)) från spår 5.")),
            Sample(id: "reminderNone", title: route, body: t("Leaves \(clock(60)). Platform not announced yet.", "Avgår \(clock(60)). Spåret är inte meddelat än.")),
            Sample(id: "platformSet", title: route, body: t("Leaves from platform 5.", "Avgår från spår 5.")),
            Sample(id: "platformChanged", title: route, body: t("Platform changed: now platform 7, was 5.", "Spårändring: nu spår 7, var 5.")),
            Sample(id: "platformArr", title: route, body: t("Arrival platform changed at \(to): now platform 3, was 2.", "Spårändring vid ankomst i \(to): nu spår 3, var 2.")),
            Sample(id: "delay", title: route, body: t("12 min late, now arriving \(clock(70)).", "12 min försenat, ankommer nu \(clock(70)).")),
            Sample(id: "cancelled", title: t("Cancelled: \(route)", "Inställt: \(route)"), body: t("This train is cancelled. Check the operator for other trains or replacement buses.", "Tåget är inställt. Kolla med operatören efter andra tåg eller ersättningsbussar."), timeSensitive: true),
            Sample(id: "shortTurned", title: route, body: t("Some stops on this train are cancelled. Open Clack for the details.", "Några stopp på tåget är inställda. Öppna Clack för detaljer."), timeSensitive: true),
            Sample(id: "changeEasy", title: t("Change at \(from)", "Byte i \(from)"), body: t("Arrive platform 3, leave platform 5. 11 min to spare.", "Kom på spår 3, fortsätt från spår 5. 11 min till godo.")),
            Sample(id: "changeTight", title: t("Tight change at \(from)", "Snävt byte i \(from)"), body: t("Arrive platform 3, leave platform 5. 4 min to spare.", "Kom på spår 3, fortsätt från spår 5. 4 min till godo.")),
            Sample(id: "changeMiss", title: t("You may miss your connection", "Du kan missa din anslutning"), body: t("You arrive 3 min after the train to Kolding leaves \(from).", "Du kommer 3 min efter att tåget mot Kolding avgått från \(from)."), timeSensitive: true),
            Sample(id: "changeCancelled", title: t("Change at \(from)", "Byte i \(from)"), body: t("Your next train to Kolding is cancelled.", "Ditt nästa tåg mot Kolding är inställt."), timeSensitive: true),
            Sample(id: "getOff", title: route, body: t("Get off at \(to) in about 9 min.", "Kliv av i \(to) om cirka 9 min.")),
            Sample(id: "welcome", title: t("Welcome to \(to)", "Välkommen till \(to)"), body: t("You arrived at \(clock(0)).", "Du kom fram \(clock(0)).")),
        ]
    }

    func label(_ id: String) -> String {
        [
            "reminder": "Departure reminder", "reminderNone": "Reminder, platform not announced", "platformSet": "Platform announced",
            "platformChanged": "Platform changed", "platformArr": "Arrival platform changed", "delay": "Delay (+12 min)",
            "cancelled": "Cancelled", "shortTurned": "Some stops cancelled", "changeEasy": "Change: easy", "changeTight": "Change: tight",
            "changeMiss": "Change: likely missed", "changeCancelled": "Change: next train cancelled", "getOff": "Get off soon",
            "welcome": "Welcome at your destination",
        ][id] ?? id
    }

    // MARK: notifications

    func fire(_ sample: Sample) async {
        let center = UNUserNotificationCenter.current()
        if NotificationManager.shared.authorization == .notDetermined { _ = await NotificationManager.shared.requestPermission() }
        await NotificationManager.shared.refresh()
        guard NotificationManager.shared.authorization == .authorized || NotificationManager.shared.authorization == .provisional else {
            message = "Notifications are off for Clack in iPhone Settings."
            return
        }
        let content = UNMutableNotificationContent()
        content.title = sample.title
        content.body = sample.body
        content.subtitle = swedish ? "SJ Snabbtåg 7205 · spår \(sample.id.hasPrefix("platform") ? "7" : "5")" : "SJ Snabbtåg 7205 · platform \(sample.id.hasPrefix("platform") ? "7" : "5")"
        content.sound = NotificationArt.sound
        content.threadIdentifier = "debug"
        content.interruptionLevel = sample.timeSensitive ? .timeSensitive : .active
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(1, delay), repeats: false)
        try? await center.add(UNNotificationRequest(identifier: "debug-\(sample.id)-\(UUID().uuidString)", content: content, trigger: trigger))
        message = "\(label(sample.id)): arrives in \(Int(max(1, delay))) s. Lock the phone to see it there."
    }

    // MARK: the trip card: one sample per moment

    /// One button per moment the card and the island can be in; each starts the card, or moves it to that moment.
    enum Moment: String, CaseIterable {
        case scheduled = "Far off (leaves in 2 h)", leaveSoon = "Leaving soon (platform 5)", platformChanged = "Platform changed to 7"
        case approaching = "Train on its way to my stop (+9)", boarding = "Boarding", enRoute = "On the way (45%)", late = "On the way, late (+12)"
        case getOffSoon = "Get off soon (8 min)", changing = "Changing trains (platform 5, 11 min)", arrived = "Arrived", cancelled = "Cancelled"
    }

    private func state(_ m: Moment) -> TripActivityAttributes.ContentState {
        func at(_ min: Double) -> Double { Date(timeIntervalSinceNow: min * 60).timeIntervalSince1970 * 1000 }
        typealias S = TripActivityAttributes.ContentState
        switch m {
        case .scheduled:
            return S(status: "scheduled", delayMin: 0, nextStop: nil, nextStopAt: nil, platform: nil, platformFor: "departure", progress: 0, departAt: at(120), arriveAt: at(153), canceled: false, phase: "scheduled")
        case .leaveSoon:
            return S(status: "scheduled", delayMin: 0, nextStop: nil, nextStopAt: nil, platform: "5", platformFor: "departure", progress: 0, departAt: at(22), arriveAt: at(55), canceled: false, phase: "leaveSoon")
        case .platformChanged:
            return S(status: "scheduled", delayMin: 0, nextStop: nil, nextStopAt: nil, platform: "7", platformFor: "departure", progress: 0, departAt: at(18), arriveAt: at(51), canceled: false, phase: "leaveSoon", note: "platformChanged")
        case .approaching:
            return S(status: "approaching", delayMin: 9, nextStop: from, nextStopAt: at(8), platform: "5", platformFor: "departure", progress: 0, departAt: at(17), arriveAt: at(50), canceled: false, phase: "approaching")
        case .boarding:
            return S(status: "boarding", delayMin: 0, nextStop: from, nextStopAt: at(4), platform: "5", platformFor: "departure", progress: 0, departAt: at(4), arriveAt: at(37), canceled: false, phase: "boarding")
        case .enRoute:
            return S(status: "en_route", delayMin: 2, nextStop: "Alvesta", nextStopAt: at(14), platform: "3", platformFor: "arrival", progress: 0.45, departAt: at(-15), arriveAt: at(18), canceled: false, phase: "enRoute")
        case .late:
            return S(status: "en_route", delayMin: 12, nextStop: "Alvesta", nextStopAt: at(20), platform: "3", platformFor: "arrival", progress: 0.5, departAt: at(-15), arriveAt: at(30), canceled: false, phase: "enRoute")
        case .getOffSoon:
            return S(status: "en_route", delayMin: 0, nextStop: to, nextStopAt: at(8), platform: "3", platformFor: "arrival", progress: 0.92, departAt: at(-32), arriveAt: at(8), canceled: false, phase: "getOffSoon")
        case .changing:
            return S(status: "arrived", delayMin: 0, nextStop: nil, nextStopAt: nil, platform: "3", platformFor: "arrival", progress: 1, departAt: at(-40), arriveAt: at(-1), canceled: false, phase: "changing", changePlatform: "5", changeAt: at(11))
        case .arrived:
            return S(status: "arrived", delayMin: 0, nextStop: nil, nextStopAt: nil, platform: "3", platformFor: "arrival", progress: 1, departAt: at(-33), arriveAt: at(0), canceled: false, phase: "arrived")
        case .cancelled:
            return S(status: "cancelled", delayMin: nil, nextStop: nil, nextStopAt: nil, platform: nil, platformFor: "departure", progress: 0, departAt: at(25), arriveAt: at(58), canceled: true, phase: "cancelled")
        }
    }

    func show(_ m: Moment) async {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            message = "Live Activities are off for Clack in iPhone Settings."
            return
        }
        let content = ActivityContent(state: state(m), staleDate: Date(timeIntervalSinceNow: 3600))
        if let activity {
            await activity.update(content)
            message = "Trip card: \(m.rawValue)"
            return
        }
        let attributes = TripActivityAttributes(legId: "debug-sample", journeyId: nil, train: "7205", from: from, to: to, fromTz: "Europe/Stockholm", toTz: "Europe/Stockholm", color: "#2ea44f")
        do {
            activity = try Activity.request(attributes: attributes, content: content, pushType: nil)
            message = "Trip card started: \(m.rawValue). Lock the phone, or press Home and hold the island."
        } catch {
            message = "Couldn't start the trip card: \(error.localizedDescription)"
        }
    }

    func endCard() async {
        for a in Activity<TripActivityAttributes>.activities where a.attributes.legId == "debug-sample" { await a.end(nil, dismissalPolicy: .immediate) }
        activity = nil
        message = "Trip card ended."
    }
}

struct TestAlertsScreen: View {
    @Environment(AppModel.self) private var app
    @Environment(L10n.self) private var l10n
    @State private var model = TestAlertsModel()
    @State private var arrivalNote: String?

    var body: some View {
        Page {
            BackLink(label: l10n.t("settings.title"))
            PageHeader(title: "Test alerts")
            Text("Debug builds only. Alerts here are local to this phone, with the wording the server uses. Set a delay, press one, then lock the phone.")
                .clack(.caption).foregroundStyle(Ink.text2)
            if let message = model.message { Banner(kind: .neutral) { Text(message) } }

            Card {
                Text("Alert in").clack(.sectionHeader).foregroundStyle(Ink.text2)
                SegmentedControl(selection: Binding(get: { model.delay }, set: { model.delay = $0 }), options: [(5, "5 s"), (15, "15 s"), (30, "30 s")], small: true)
                ForEach(model.samples(language: app.settings.language)) { sample in
                    Button { Task { await model.fire(sample) } } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(model.label(sample.id)).clack(.rowTitle).foregroundStyle(Ink.text)
                            Text(sample.body).clack(.caption).foregroundStyle(Ink.text2).multilineTextAlignment(.leading)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading).padding(.vertical, 6)
                    }
                    .buttonStyle(.plain)
                }
            }

            Card {
                Text("Trip card (Lock Screen and Dynamic Island)").clack(.sectionHeader).foregroundStyle(Ink.text2)
                Text("Press a moment to start the card there, then another to move it. Compare the small island on each.")
                    .clack(.caption).foregroundStyle(Ink.text2)
                ForEach(TestAlertsModel.Moment.allCases, id: \.self) { m in
                    Button(m.rawValue) { Task { await model.show(m) } }.buttonStyle(.clack(wide: true))
                }
                Button("End the trip card") { Task { await model.endCard() } }.buttonStyle(.clack(.danger, wide: true))
            }

            Card {
                Text("Arrival welcome").clack(.sectionHeader).foregroundStyle(Ink.text2)
                Button("Open it for my latest trip") {
                    Task {
                        let legs = (try? await app.client.legs()) ?? []
                        guard let last = legs.max(by: { ($0.schedDep?.ms ?? 0) < ($1.schedDep?.ms ?? 0) }) else {
                            arrivalNote = "You have no trips yet."
                            return
                        }
                        app.arrivals.preview(ArrivalMoment(legId: last.id, journeyId: last.journeyId))
                        arrivalNote = nil
                    }
                }
                .buttonStyle(.clack(wide: true))
                if let arrivalNote { Text(arrivalNote).clack(.caption).foregroundStyle(Ink.text2) }
            }
        }
    }
}
#endif

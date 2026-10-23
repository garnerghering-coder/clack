//
//  TestAlertsScreen.swift
//  Clack
//

#if DEBUG
import ActivityKit
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

    func fire(_ sample: Sample, after seconds: Double? = nil) async {
        let center = UNUserNotificationCenter.current()
        if await NotificationManager.shared.authorization == .notDetermined { _ = await NotificationManager.shared.requestPermission() }
        await NotificationManager.shared.refresh()
        guard NotificationManager.shared.authorization == .authorized || NotificationManager.shared.authorization == .provisional else {
            message = "Notifications are off for Clack in iPhone Settings."
            return
        }
        let content = UNMutableNotificationContent()
        content.title = sample.title
        content.body = sample.body
        content.sound = .default
        content.threadIdentifier = "debug"
        content.interruptionLevel = sample.timeSensitive ? .timeSensitive : .active
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(1, seconds ?? delay), repeats: false)
        try? await center.add(UNNotificationRequest(identifier: "debug-\(sample.id)-\(UUID().uuidString)", content: content, trigger: trigger))
        message = "\(label(sample.id)): arrives in \(Int(max(1, seconds ?? delay))) s. Lock the phone to see it there."
    }

    func fireAll(language: Language) async {
        var wait = delay
        for sample in samples(language: language) {
            await fire(sample, after: wait)
            wait += 6
        }
        message = "All \(samples(language: language).count) alerts: the first in \(Int(delay)) s, then one every 6 s."
    }

    // MARK: the trip card

    enum CardState: String, CaseIterable {
        case scheduled = "Upcoming (platform 5)", approaching = "On its way to my stop (+9)", boarding = "Boarding", enRoute = "En route (45%)"
        case late = "Late +12", platform = "Platform changed to 7", cancelled = "Cancelled", arrived = "Arrived"
    }

    private func state(_ s: CardState) -> TripActivityAttributes.ContentState {
        let dep = Date(timeIntervalSinceNow: 25 * 60).timeIntervalSince1970 * 1000
        let arr = Date(timeIntervalSinceNow: 58 * 60).timeIntervalSince1970 * 1000
        func next(_ min: Double) -> Double { Date(timeIntervalSinceNow: min * 60).timeIntervalSince1970 * 1000 }
        switch s {
        case .scheduled:
            return .init(status: "scheduled", delayMin: 0, nextStop: nil, nextStopAt: nil, platform: "5", platformFor: "departure", progress: 0, departAt: dep, arriveAt: arr, canceled: false)
        case .approaching:
            return .init(status: "approaching", delayMin: 9, nextStop: from, nextStopAt: next(8), platform: "5", platformFor: "departure", progress: 0, departAt: dep + 9 * 60_000, arriveAt: arr + 9 * 60_000, canceled: false)
        case .boarding:
            return .init(status: "boarding", delayMin: 0, nextStop: from, nextStopAt: dep, platform: "5", platformFor: "departure", progress: 0, departAt: dep, arriveAt: arr, canceled: false)
        case .enRoute:
            return .init(status: "en_route", delayMin: 2, nextStop: "Alvesta", nextStopAt: next(14), platform: "3", platformFor: "arrival", progress: 0.45, departAt: next(-15), arriveAt: next(18), canceled: false)
        case .late:
            return .init(status: "en_route", delayMin: 12, nextStop: "Alvesta", nextStopAt: next(20), platform: "3", platformFor: "arrival", progress: 0.5, departAt: next(-15), arriveAt: next(30), canceled: false)
        case .platform:
            return .init(status: "boarding", delayMin: 0, nextStop: from, nextStopAt: dep, platform: "7", platformFor: "departure", progress: 0, departAt: dep, arriveAt: arr, canceled: false)
        case .cancelled:
            return .init(status: "cancelled", delayMin: nil, nextStop: nil, nextStopAt: nil, platform: nil, platformFor: "departure", progress: 0, departAt: dep, arriveAt: arr, canceled: true)
        case .arrived:
            return .init(status: "arrived", delayMin: 0, nextStop: nil, nextStopAt: nil, platform: "3", platformFor: "arrival", progress: 1, departAt: next(-30), arriveAt: next(0), canceled: false)
        }
    }

    func show(_ s: CardState) async {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            message = "Live Activities are off for Clack in iPhone Settings."
            return
        }
        let content = ActivityContent(state: state(s), staleDate: Date(timeIntervalSinceNow: 3600))
        if let activity {
            await activity.update(content)
            message = "Trip card: \(s.rawValue)"
            return
        }
        let attributes = TripActivityAttributes(legId: "debug-sample", journeyId: nil, train: "7205", from: from, to: to, fromTz: "Europe/Stockholm", toTz: "Europe/Stockholm", color: "#2ea44f")
        do {
            activity = try Activity.request(attributes: attributes, content: content, pushType: nil)
            message = "Trip card started: \(s.rawValue). Lock the phone, or go Home to see it in the Dynamic Island."
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
                Button("Send all alerts, 6 s apart") { Task { await model.fireAll(language: app.settings.language) } }
                    .buttonStyle(.clack(.primary, wide: true))
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
                ForEach(TestAlertsModel.CardState.allCases, id: \.self) { s in
                    Button(s.rawValue) { Task { await model.show(s) } }.buttonStyle(.clack(wide: true))
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

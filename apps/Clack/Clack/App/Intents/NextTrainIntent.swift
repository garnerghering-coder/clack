//
//  NextTrainIntent.swift
//  Clack
//

import AppIntents
import ClackCore
import Foundation

/// "When's my train?" (designer, 2026-11-14; owner: build it now): Siri, Spotlight or the Action button answer with your
/// train's departure, platform and delay, or its arrival when you're on it, without opening the app. The words are the
/// catalog's (ClackKit), in the language set in Clack; the trips are the server's, or the phone's kept copy when it
/// can't be reached.
struct NextTrainIntent: AppIntent {
    // App Intents read their titles from the app's own bundle only, at build time: these three live in the app
    // target's Localizable.xcstrings (English and Swedish), the one exception to ClackKit's catalog. What Siri says is
    // the catalog's.
    static let title: LocalizedStringResource = "When's my train?"
    static let description = IntentDescription("Your next train: when it leaves, from which platform, and whether it's late.")

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let answer = await NextTrainAnswer.text()
        return .result(dialog: IntentDialog(LocalizedStringResource(stringLiteral: answer)))
    }
}

/// The sentence the intent says, built from the same rules as Trips' featured card (`TripsLogic.hero`).
enum NextTrainAnswer {
    static func text() async -> String {
        let client = APIClient(userID: Identity.current(), cache: OfflineCache())
        let settings: Settings? = await client.saved(["settings"])
        var legs: [Leg] = (try? await client.legs()) ?? []
        if legs.isEmpty { legs = await client.saved(["legs"]) ?? [] }
        let now = Date.now.timeIntervalSince1970 * 1000
        return await MainActor.run {
            let l10n = L10n(language: settings?.language ?? AppModel.appLanguage(forPreferred: Locale.preferredLanguages) ?? .en)
            let clock = settings?.clock ?? .h24
            let (upcoming, past) = TripsLogic.partition(legs, now: now)
            guard let hero = TripsLogic.hero(upcoming: upcoming, past: past, now: now), hero.state != .arrived else {
                return l10n.t("intents.nextTrain.none")
            }
            let leg = hero.leg
            let train = Format.service(leg.operator?.name, leg.trainNumber)
            let ends = TripsLogic.expected(leg)
            let delay: String? = leg.canceled ? l10n.t("intents.nextTrain.cancelled")
                : (hero.state == .active ? leg.arrDelayMin : leg.depDelayMin).map { $0 > 0 ? l10n.t("passport.minutesLate", count: $0) : l10n.t("delay.on_time") }
            if hero.state == .active {
                return l10n.t("intents.nextTrain.arrives", [
                    "train": train.isEmpty ? l10n.t("intents.nextTrain.yourTrain") : train,
                    "to": leg.destination?.name ?? "",
                    "time": Format.time(ends.arr, tz: leg.destination?.tz ?? TripsLogic.tz(leg), clock: clock),
                    "delay": delay.map { ", \($0)" } ?? "",
                ])
            }
            return l10n.t("intents.nextTrain.leaves", [
                "train": train.isEmpty ? l10n.t("intents.nextTrain.yourTrain") : train,
                "to": leg.destination?.name ?? "",
                "day": Format.day(ends.dep ?? now, tz: TripsLogic.tz(leg), now: now, language: l10n.language),
                "time": Format.time(ends.dep, tz: TripsLogic.tz(leg), clock: clock),
                "platform": leg.depPlatform.map { " " + l10n.t("intents.nextTrain.fromPlatform", ["platform": $0]) } ?? "",
                "delay": delay.map { ", \($0)" } ?? "",
            ])
        }
    }
}

struct ClackShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: NextTrainIntent(),
            phrases: [
                "When's my train in \(.applicationName)",
                "When does my train leave in \(.applicationName)",
                "Where's my train in \(.applicationName)",
            ],
            shortTitle: "When's my train?",
            systemImageName: "tram.fill"
        )
    }
}

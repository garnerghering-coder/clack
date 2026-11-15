//
//  Usage.swift
//  Clack
//

import ClackCore
import Foundation
import MetricKit
import SwiftUI

/// How Clack is used, counted on the phone and sent to Clack's own server once a day (owner, 2026-10-25): which
/// screens are opened and features used, which station pairs are searched, which errors show, a relaunch soon after an
/// error, and Apple's crash and hang reports (MetricKit). Nothing about who: the server keeps daily totals with no id.
/// Off until you say yes (asked once after the first trip; Settings > Usage data); off, nothing is counted or sent.
@MainActor
final class Usage: NSObject, MXMetricManagerSubscriber {
    static let shared = Usage()

    enum Kind: String { case screen, feature, route, error, relaunch }

    private static let enabledKey = "clack.usage.enabled"
    private static let countsKey = "clack.usage.counts"
    private static let lastSentKey = "clack.usage.lastSent"
    private static let lastErrorKey = "clack.usage.lastError"
    private static let reportsKey = "clack.usage.reports"
    private static let askedKey = "clack.usage.asked"

    /// Whether the one ask has been made (or a choice made in Settings).
    var asked: Bool {
        get { defaults.bool(forKey: Self.askedKey) }
        set { defaults.set(newValue, forKey: Self.askedKey) }
    }

    private let defaults = UserDefaults.standard

    /// Off until you say yes: asked once after your first trip, or Settings > Usage data (owner, 2026-11-01).
    var enabled: Bool {
        get { defaults.object(forKey: Self.enabledKey) as? Bool ?? false }
        set {
            defaults.set(newValue, forKey: Self.enabledKey)
            if !newValue { defaults.removeObject(forKey: Self.countsKey); defaults.removeObject(forKey: Self.reportsKey) }
        }
    }

    /// Counts by day ("2026-10-25") then "kind|name".
    private var counts: [String: [String: Int]] {
        get { defaults.dictionary(forKey: Self.countsKey) as? [String: [String: Int]] ?? [:] }
        set { defaults.set(newValue, forKey: Self.countsKey) }
    }

    private static var today: String {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(identifier: "UTC")
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: .now)
    }

    /// One more of something. Names are short identifiers ("trips.add", "740000001>740000005"), never a person's text.
    func count(_ kind: Kind, _ name: String, by n: Int = 1) {
        guard enabled, !name.isEmpty else { return }
        var all = counts
        all[Self.today, default: [:]]["\(kind.rawValue)|\(name)", default: 0] += n
        counts = all
    }

    /// An error was shown; a relaunch within two minutes of one is counted too (someone resetting the app after it).
    func error(_ name: String) {
        count(.error, name)
        defaults.set(["name": name, "at": Date.now.timeIntervalSince1970], forKey: Self.lastErrorKey)
    }

    /// At launch: subscribe to Apple's diagnostics, note a relaunch after an error, send what's waiting.
    func start(client: @escaping @MainActor () -> APIClient) {
        self.client = client
        MXMetricManager.shared.add(self)
        if let last = defaults.dictionary(forKey: Self.lastErrorKey), let at = last["at"] as? Double, let name = last["name"] as? String,
           Date.now.timeIntervalSince1970 - at < 120 {
            count(.relaunch, name)
        }
        defaults.removeObject(forKey: Self.lastErrorKey)
        Task { await flush() }
    }

    private var client: (@MainActor () -> APIClient)?

    /// Sends the counts of past days (and today's, once a day), then forgets them. Quiet on failure: they wait.
    func flush(force: Bool = false) async {
        guard enabled, let client = client?() else { return }
        let lastSent = defaults.double(forKey: Self.lastSentKey)
        guard force || Date.now.timeIntervalSince1970 - lastSent > 6 * 3600 else { return }
        let all = counts
        for (day, items) in all {
            let events = items.compactMap { key, n -> UsageEvent? in
                let parts = key.split(separator: "|", maxSplits: 1).map(String.init)
                return parts.count == 2 ? UsageEvent(kind: parts[0], name: parts[1], count: n) : nil
            }
            guard !events.isEmpty else { continue }
            do {
                // Without the phone's id (review P7): the server keeps daily totals and never needs to know whose.
                try await client.anonymous("POST", ["usage"], body: UsageBatch(day: day, events: events))
                var left = counts
                left[day] = nil
                counts = left
            } catch { return }
        }
        if let reports = defaults.array(forKey: Self.reportsKey) as? [[String: Any]], !reports.isEmpty {
            let list = reports.compactMap { r -> DiagnosticReport? in
                guard let kind = r["kind"] as? String, let signature = r["signature"] as? String else { return nil }
                return DiagnosticReport(kind: kind, signature: signature, count: r["count"] as? Int ?? 1)
            }
            if (try? await client.anonymous("POST", ["diagnostics"], body: DiagnosticsBatch(build: Self.build, reports: list))) != nil {
                defaults.removeObject(forKey: Self.reportsKey)
            }
        }
        defaults.set(Date.now.timeIntervalSince1970, forKey: Self.lastSentKey)
    }

    static var build: String { Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "unknown" }

    // MARK: MetricKit

    /// Apple hands over the last day's crash and hang reports, at most once a day. Kept as a kind and a short signature
    /// (the exception or signal, and the top frame of Clack's own code), never the whole report.
    nonisolated func didReceive(_ payloads: [MXDiagnosticPayload]) {
        var found: [[String: Any]] = []
        for payload in payloads {
            for crash in payload.crashDiagnostics ?? [] {
                let what = [crash.exceptionType.map { "exception \($0)" }, crash.signal.map { "signal \($0)" }].compactMap { $0 }.joined(separator: " ")
                found.append(["kind": "crash", "signature": Self.signature(what, crash.callStackTree), "count": 1])
            }
            for hang in payload.hangDiagnostics ?? [] {
                found.append(["kind": "hang", "signature": Self.signature("hang", hang.callStackTree), "count": 1])
            }
        }
        guard !found.isEmpty else { return }
        Task { @MainActor in
            guard enabled else { return }
            let kept = (defaults.array(forKey: Self.reportsKey) as? [[String: Any]]) ?? []
            defaults.set(Array((kept + found).suffix(50)), forKey: Self.reportsKey)
            await flush(force: true)
        }
    }

    /// "exception 10 signal 6 · Foundation+1234 > UIKitCore+5678 > UIKitCore+91 > Clack+12345": what happened, the top
    /// frames of the crashed thread (any binary: the cause is often in UIKit or MapLibre, as with the notification tap
    /// in build 83), and the first frame in Clack's own binary when it isn't among them. Read from the report's JSON,
    /// not by pattern: the key order isn't fixed, and the old pattern found nothing in either crash of build 83.
    nonisolated static func signature(_ what: String, _ tree: MXCallStackTree) -> String {
        signature(what, json: tree.jsonRepresentation())
    }

    nonisolated static func signature(_ what: String, json: Data) -> String {
        var frames: [String] = []
        var clack: String?
        if let root = try? JSONSerialization.jsonObject(with: json) as? [String: Any],
           let stacks = root["callStacks"] as? [[String: Any]] {
            let thread = stacks.first { ($0["threadAttributed"] as? Bool) == true } ?? stacks.first
            // The crashed thread is a chain: each frame's first sub-frame is the one it was called from.
            var frame = (thread?["callStackRootFrames"] as? [[String: Any]])?.first
            while let f = frame {
                let name = (f["binaryName"] as? String) ?? "?"
                let label = "\(name)+\((f["offsetIntoBinaryTextSegment"] as? Int) ?? 0)"
                if frames.count < 4 { frames.append(label) }
                if clack == nil, name.hasPrefix("Clack") { clack = label }
                if frames.count >= 4, clack != nil { break }
                frame = (f["subFrames"] as? [[String: Any]])?.first
            }
        }
        if let clack, !frames.contains(clack) { frames.append(clack) }
        let head = what.isEmpty ? "unknown" : what
        return frames.isEmpty ? head : "\(head) · \(frames.joined(separator: " > "))"
    }
}

private struct UsageEvent: Encodable, Sendable { let kind: String; let name: String; let count: Int }
private struct UsageBatch: Encodable, Sendable { let day: String; let events: [UsageEvent] }
private struct DiagnosticReport: Encodable, Sendable { let kind: String; let signature: String; let count: Int }
private struct DiagnosticsBatch: Encodable, Sendable { let build: String; let reports: [DiagnosticReport] }

extension View {
    /// Counts a screen when it appears.
    func countsScreen(_ name: String) -> some View { onAppear { Usage.shared.count(.screen, name) } }
    /// Counts an error when its banner appears.
    func countsError(_ name: String) -> some View { onAppear { Usage.shared.error(name) } }
}

/// The one ask for usage data (owner, 2026-11-01: off until you say yes, asked once after your first trip).
@MainActor
@Observable
final class UsageAsk {
    static let shared = UsageAsk()
    var show = false

    /// When this phone first opened Clack; set on the first check of the first run.
    static let firstOpenedKey = "clack.usage.firstOpened"
    /// Whether Clack had been opened before this run started: read once per run, before the first check stores it.
    private let openedBefore: Bool = {
        let defaults = UserDefaults.standard
        if defaults.object(forKey: UsageAsk.firstOpenedKey) != nil { return true }
        defaults.set(Date.now.timeIntervalSince1970, forKey: UsageAsk.firstOpenedKey)
        return false
    }()

    /// After the trips load: on a later start than the first, once one of the trips has ended, ask (once). Never on
    /// the first run, even when trips come back with it (a reinstall keeps them) or a past trip was just added (user
    /// test 2026-11-07, run 2: it was the first thing a new phone saw); the privacy page says the same
    /// (`privacy.usageBody`).
    func check(_ legs: [Leg], now: Double = Date.now.timeIntervalSince1970 * 1000) {
        guard !Usage.shared.asked, openedBefore else { return }
        if legs.contains(where: { $0.actualArr != nil || $0.live?.status == .arrived || ($0.schedArr?.ms ?? .infinity) < now }) {
            Usage.shared.asked = true
            show = true
        }
    }
}

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
/// Settings > Usage data turns it off; with it off nothing is counted or sent.
@MainActor
final class Usage: NSObject, MXMetricManagerSubscriber {
    static let shared = Usage()

    enum Kind: String { case screen, feature, route, error, relaunch }

    private static let enabledKey = "clack.usage.enabled"
    private static let countsKey = "clack.usage.counts"
    private static let lastSentKey = "clack.usage.lastSent"
    private static let lastErrorKey = "clack.usage.lastError"
    private static let reportsKey = "clack.usage.reports"

    private let defaults = UserDefaults.standard

    /// On unless turned off in Settings.
    var enabled: Bool {
        get { defaults.object(forKey: Self.enabledKey) as? Bool ?? true }
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
                try await client.perform("POST", ["usage"], body: UsageBatch(day: day, events: events))
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
            if (try? await client.perform("POST", ["diagnostics"], body: DiagnosticsBatch(build: Self.build, reports: list))) != nil {
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

    /// "exception 1 · Clack +12345": what happened and the first frame in Clack's own binary.
    nonisolated private static func signature(_ what: String, _ tree: MXCallStackTree) -> String {
        let json = String(data: tree.jsonRepresentation(), encoding: .utf8) ?? ""
        let frame = json.range(of: #""binaryName"\s*:\s*"Clack[^"]*"[^}]*"offsetIntoBinaryTextSegment"\s*:\s*\d+"#, options: .regularExpression)
            .map { String(json[$0]) }
            .map { $0.replacingOccurrences(of: #"[^\w+ ]"#, with: " ", options: .regularExpression) }
            .map { $0.split(separator: " ").filter { $0 != "binaryName" && $0 != "offsetIntoBinaryTextSegment" }.joined(separator: " ") }
        return [what.isEmpty ? "unknown" : what, frame].compactMap { $0 }.joined(separator: " · ")
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

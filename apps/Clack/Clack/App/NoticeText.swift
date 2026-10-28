//
//  NoticeText.swift
//  Clack
//

import ClackCore
import Foundation
import Observation
#if canImport(FoundationModels)
import FoundationModels
#endif
#if canImport(Translation)
import Translation
#endif

/// A notice still in its source's language (Rejseplanen's Danish, when the phrase table didn't know it), made short
/// and readable on the phone (owner, 2026-10-28): Apple's on-device model rewrites it as one short line in the app's
/// language where it can, else the on-device translator translates it where that language is installed, else it stays
/// as written, cut to `maxWords`. Nothing leaves the phone. Results are kept for the session.
@MainActor
@Observable
final class NoticeText {
    static let shared = NoticeText()

    /// Longest line shown for a notice, in words.
    static let maxWords = 16

    struct Line: Equatable {
        let text: String
        /// Rewritten or translated on the phone (shown as such), not the source's own words.
        let translated: Bool
    }

    private var done: [String: Line] = [:]
    @ObservationIgnored private var asked = Set<String>()

    /// What to show now for `line` in `language` (`en`, `sv`): the short version once ready, the original cut to
    /// `maxWords` until then. Asking starts the work once.
    func line(_ line: CauseLine, language: String) -> Line {
        guard let source = line.lang, source != language else { return Line(text: line.text, translated: false) }
        let key = "\(source)>\(language)|\(line.text)"
        if let hit = done[key] { return hit }
        if asked.insert(key).inserted {
            Task { [weak self] in
                guard let short = await Self.rewrite(line.text, from: source, to: language) else { return }
                self?.done[key] = Line(text: Self.clip(short), translated: true)
            }
        }
        return Line(text: Self.clip(line.text), translated: false)
    }

    /// At most `maxWords` words, with "…" when cut.
    static func clip(_ text: String) -> String {
        let words = text.split(whereSeparator: \.isWhitespace)
        guard words.count > maxWords else { return text }
        return words.prefix(maxWords).joined(separator: " ") + "…"
    }

    private static func rewrite(_ text: String, from source: String, to target: String) async -> String? {
        if #available(iOS 26.0, *) {
            #if canImport(FoundationModels)
            let model = SystemLanguageModel.default
            if model.isAvailable, model.supportsLocale(Locale(identifier: target)) {
                let language = target == "sv" ? "Swedish" : "English"
                let session = LanguageModelSession(instructions: """
                    You rewrite short rail service notices for travellers. You MUST respond in \(language), with one plain \
                    sentence of at most 12 words. Keep station names, platform numbers and dates exactly. Never add \
                    anything the notice doesn't say. No links, no greetings.
                    """)
                if let answer = try? await session.respond(to: "Notice: \(text)") {
                    let line = answer.content.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !line.isEmpty { return line }
                }
            }
            #endif
            #if canImport(Translation)
            let session = TranslationSession(installedSource: Locale.Language(identifier: source), target: Locale.Language(identifier: target))
            if let answer = try? await session.translate(text) { return answer.targetText }
            #endif
        }
        return nil
    }
}

extension L10n {
    /// A stop's notes as shown: station-facility notices left out, anything still in its source's language shortened
    /// or translated on the phone (marked "translated" when it is).
    func shownNotes(_ causes: [LegStop.Cause]) -> [String] {
        causeLines(causes).map { shown($0) }
    }

    /// One note as shown (see `shownNotes`).
    func shown(_ line: CauseLine) -> String {
        let l = NoticeText.shared.line(line, language: language.rawValue)
        return l.translated ? "\(l.text) · \(t("notice.translated"))" : l.text
    }
}

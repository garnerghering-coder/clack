//
//  NoticeText.swift
//  Clack
//

import ClackCore
import Foundation
import NaturalLanguage
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

    /// What to show now for `line` in `language` (an app language code: `en`, `sv`, `da`, `nb`, …): the short version
    /// once ready, the original cut to `maxWords` until then. Asking starts the work once. A line already in the
    /// reader's language (Entur's "no" for a Norwegian reader) is shown as written.
    func line(_ line: CauseLine, language: String) -> Line {
        guard let source = line.lang, !Language.same(source, language) else { return Line(text: line.text, translated: false) }
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

    /// The on-device model's answer keeps only what the notice says: every number in it (a date, a time, a platform)
    /// must be in the notice too. It once wrote "on 12 June" for a Danish notice with no date at all (build 84 check,
    /// 2026-11-15); an answer like that is dropped and the notice shows as written (or as the translator has it).
    static func addsNothing(_ answer: String, to source: String) -> Bool {
        func numbers(_ s: String) -> Set<String> {
            // "08" and "8" are the same number.
            Set(s.split(whereSeparator: { !$0.isNumber }).map { part in
                let digits = String(part.drop(while: { $0 == "0" }))
                return digits.isEmpty ? "0" : digits
            })
        }
        return numbers(answer).isSubset(of: numbers(source))
    }

    /// The answer is in the language asked for: the model sometimes hands the notice back as it was (a Danish line
    /// marked translated, build 84 check), which would then show as a translation.
    static func isIn(_ target: String, _ answer: String) -> Bool {
        let recognizer = NLLanguageRecognizer()
        recognizer.processString(answer)
        guard let found = recognizer.dominantLanguage else { return true }
        return Language.same(found.rawValue, target)
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
                let language = Self.englishName(target)
                let session = LanguageModelSession(instructions: """
                    You rewrite short rail service notices for travellers. You MUST respond in \(language), with one plain \
                    sentence of at most 12 words. Keep station names, platform numbers and dates exactly. Never add \
                    anything the notice doesn't say. No links, no greetings.
                    """)
                if let answer = try? await session.respond(to: "Notice: \(text)") {
                    let line = answer.content.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !line.isEmpty, Self.addsNothing(line, to: text), Self.isIn(target, line) { return line }
                }
            }
            #endif
            #if canImport(Translation)
            let session = TranslationSession(installedSource: translatorLanguage(source), target: translatorLanguage(target))
            if let answer = try? await session.translate(text) { return answer.targetText }
            #endif
        }
        return nil
    }

    /// A longer text (a disruption's whole message) in `language`, translated whole, never shortened: the on-device
    /// translator where the pair is installed, else Apple's on-device model told to translate and add nothing, else
    /// as written. Asking starts the work once.
    func paragraph(_ line: CauseLine, language: String) -> Line {
        guard let source = line.lang, !Language.same(source, language) else { return Line(text: line.text, translated: false) }
        let key = "¶\(source)>\(language)|\(line.text)"
        if let hit = done[key] { return hit }
        if asked.insert(key).inserted {
            Task { [weak self] in
                guard let whole = await Self.translate(line.text, from: source, to: language) else { return }
                self?.done[key] = Line(text: whole, translated: true)
            }
        }
        return Line(text: line.text, translated: false)
    }

    /// A translation made with Apple's translator after the person let it download the language (the problem sheet's
    /// "Translate" button): kept, so the list and the sheet show it from now on.
    func keep(_ line: CauseLine, language: String, translation: String) {
        guard let source = line.lang else { return }
        done["¶\(source)>\(language)|\(line.text)"] = Line(text: translation, translated: true)
    }

    /// Norwegian comes from the feeds as "no"; the app and the translator know it as Bokmål ("nb").
    static func translatorLanguage(_ code: String) -> Locale.Language {
        Locale.Language(identifier: Language.normalized(code))
    }

    /// The language's name in English, for the model's instructions ("You MUST respond in Danish").
    static func englishName(_ code: String) -> String {
        Language.known(code)?.englishName ?? "English"
    }

    private static func translate(_ text: String, from source: String, to target: String) async -> String? {
        if #available(iOS 26.0, *) {
            #if canImport(Translation)
            let session = TranslationSession(installedSource: translatorLanguage(source), target: translatorLanguage(target))
            if let answer = try? await session.translate(text) { return answer.targetText }
            #endif
            #if canImport(FoundationModels)
            let model = SystemLanguageModel.default
            if model.isAvailable, model.supportsLocale(Locale(identifier: target)) {
                let language = Self.englishName(target)
                let session = LanguageModelSession(instructions: """
                    You translate rail service notices into \(language). Translate the whole notice faithfully, sentence \
                    by sentence. Keep station names, platform numbers, times and dates exactly. Never add, explain or \
                    leave out anything. Reply with the translation only.
                    """)
                if let answer = try? await session.respond(to: text) {
                    let out = answer.content.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !out.isEmpty, Self.addsNothing(out, to: text), Self.isIn(target, out) { return out }
                }
            }
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

    /// A longer text as shown: translated whole on the phone when it's in another language (see `paragraph`).
    func shownWhole(_ line: CauseLine) -> NoticeText.Line {
        // Danish messages made only of the table's checked sentences read exactly so, on every phone but a Danish
        // reader's, who gets the message as Rejseplanen wrote it.
        if line.lang == "da", language != .da,
           let checked = DelayCauses.danishSentences(line.text, translate: { t($0, $1) }) {
            return NoticeText.Line(text: checked, translated: true)
        }
        return NoticeText.shared.paragraph(line, language: language.rawValue)
    }
}

//
//  DelayCausesDanishSentencesTests.swift
//  Clack
//

@testable import ClackCore
import Foundation
import Testing

/// Network now's Danish problems in the app's language from the checked sentences (build 85), whole or not at all.
struct DelayCausesDanishSentencesTests {
    private let echo: (String, [String: String]) -> String = { key, values in
        ([key] + values.sorted { $0.key < $1.key }.map { "\($0.key)=\($0.value)" }).joined(separator: "|")
    }

    @Test func aMessageOfKnownSentencesIsTranslatedWhole() {
        let text = "Bemærk, at du skal med Togbus på denne rejse. Du kan ikke tage din cykel med i Togbussen."
        #expect(DelayCauses.danishSentences(text, translate: echo) == "disruption.dk.takeBus disruption.dk.noBikes")
    }

    @Test func thePlacesAreKept() {
        #expect(DelayCauses.danishSentences("Der kører færre tog mellem Helsingør og København H", translate: echo)
            == "disruption.dk.fewerTrains|a=Helsingør|b=København H")
    }

    @Test func oneUnknownSentenceLeavesItToTheTranslator() {
        #expect(DelayCauses.danishSentences("Ændringen skyldes sporarbejde. Toget holder ved spor 3.", translate: echo) == nil)
    }

    @Test func aLinkIsNotASentenceBreak() {
        #expect(DelayCauses.danishSentences("Derfor varer rejsen længere end normalt. Læs mere her: dsb.dk", translate: echo)
            == "disruption.dk.longer disruption.dk.moreAtDsb")
    }
}

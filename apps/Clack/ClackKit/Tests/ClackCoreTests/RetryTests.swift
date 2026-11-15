//
//  RetryTests.swift
//  ClackTests
//

import Foundation
import Testing
@testable import ClackCore

struct BackoffTests {
    /// The top of every draw: the ceiling itself.
    private let top: (ClosedRange<Double>) -> Double = { $0.upperBound }

    @Test func doublesFromTheBaseUpToTheCap() {
        var b = Backoff(base: 1, factor: 2, cap: 30)
        let delays = (0..<8).map { _ in b.next(random: top) }
        #expect(delays == [1, 2, 4, 8, 16, 30, 30, 30])
        #expect(b.failures == 8)
    }

    @Test func fullJitterStaysBetweenTheShortestAndTheCeiling() {
        var b = Backoff()
        for failures in 1...12 {
            let delay = b.next()
            #expect(delay >= Backoff.shortest)
            #expect(delay <= b.ceiling(after: failures))
        }
        // The bottom of a draw is not zero: never asked again in the same instant.
        var low = Backoff()
        #expect(low.next(random: { $0.lowerBound }) == Backoff.shortest)
    }

    @Test func aRetryAfterTakesPrecedenceOverTheComputedWait() {
        var b = Backoff(cap: 30)
        #expect(b.next(retryAfter: 45, random: top) == 45)
        #expect(b.failures == 1)
        // A wrong header can't park a screen for hours.
        #expect(b.next(retryAfter: 86_400, random: top) == Backoff.longestRetryAfter)
        // Nil or zero: the backoff's own.
        #expect(b.next(retryAfter: 0, random: top) == 4)
    }

    @Test func theServersRetryIsTheShortestWait() {
        var b = Backoff()
        #expect(b.next(atLeast: 5, random: top) == 5)
        #expect(b.next(atLeast: 5, random: top) == 5)
        #expect(b.next(atLeast: 5, random: top) == 5)
        #expect(b.next(atLeast: 5, random: top) == 8)
    }

    @Test func anAnswerResetsIt() {
        var b = Backoff()
        _ = b.next(random: top)
        _ = b.next(random: top)
        b.reset()
        #expect(b.failures == 0)
        #expect(b.next(random: top) == 1)
    }
}

struct RetrierTests {
    private let top: (ClosedRange<Double>) -> Double = { $0.upperBound }
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    @Test func aReadGivesUpAfterFiveTries() {
        var r = Retrier(.read)
        let delays = (0..<4).compactMap { _ in r.failed(.offline, now: now, random: top) }
        #expect(delays == [1, 2, 4, 8])
        #expect(r.status == .retrying(attempt: 4, next: now.addingTimeInterval(8), kind: .offline))
        #expect(r.failed(.offline, now: now, random: top) == nil)
        #expect(r.status == .gaveUp(.offline))
    }

    @Test func noneNeverRetries() {
        var r = Retrier(.none)
        #expect(r.failed(.serverDown, now: now, random: top) == nil)
        #expect(r.status == .gaveUp(.serverDown))
    }

    @Test func aRefusalIsNeverRetriedButAPollKeepsItsPace() {
        var read = Retrier(.read)
        #expect(read.failed(.rejected("bad date"), now: now, random: top) == nil)
        #expect(read.failed(.notFound, now: now, random: top) == nil)
        #expect(read.failed(.serverError, now: now, random: top) == nil)
        var poll = Retrier(.poll(every: 30))
        #expect(poll.failed(.notFound, now: now, random: top) == 30)
        #expect(poll.status == .gaveUp(.notFound))
    }

    @Test func aPollKeepsItsPaceWhileHealthyAndBacksOffToTwoMinutes() {
        var r = Retrier(.poll(every: 30))
        #expect(r.succeeded() == 30)
        let delays = (0..<8).compactMap { _ in r.failed(.timeout, now: now, random: top) }
        #expect(delays == [2, 4, 8, 16, 32, 64, 120, 120])
        #expect(r.succeeded() == 30)
        #expect(r.status == .idle)
        #expect(r.failed(.timeout, now: now, random: top) == 2)
    }

    @Test func aStreamNeverGivesUpAndCapsAtThirtySeconds() {
        var r = Retrier(.stream)
        let delays = (0..<40).compactMap { _ in r.failed(.serverDown, now: now, random: top) }
        #expect(delays.count == 40)
        #expect(delays.prefix(6) == [1, 2, 4, 8, 16, 30])
        #expect(delays.max() == 30)
    }

    @Test func tooManyRequestsWaitsWhatTheServerSaid() {
        var r = Retrier(.read)
        #expect(r.failed(.rateLimited(retryAfter: 12), now: now, random: top) == 12)
        #expect(r.status.next == now.addingTimeInterval(12))
        #expect(r.status.kind == .rateLimited(retryAfter: 12))
    }

    @Test func cancelledStops() {
        var r = Retrier(.stream)
        #expect(r.failed(.cancelled, now: now) == nil)
        #expect(r.status == .idle)
    }
}

struct ClassifyTests {
    @Test func urlErrors() {
        #expect(APIError.classify(URLError(.notConnectedToInternet)) == .offline)
        #expect(APIError.classify(URLError(.networkConnectionLost)) == .offline)
        #expect(APIError.classify(URLError(.timedOut)) == .timeout)
        #expect(APIError.classify(URLError(.cannotConnectToHost)) == .serverDown)
        #expect(APIError.classify(URLError(.badServerResponse)) == .serverDown)
        #expect(APIError.classify(URLError(.cancelled)) == .cancelled)
        #expect(APIError.classify(CancellationError()) == .cancelled)
    }

    @Test func answersByStatus() {
        func kind(_ status: Int, retryAfter: TimeInterval? = nil) -> APIError.Kind {
            APIError.classify(APIError(status: status, message: "m", duplicateOf: nil, retryAfter: retryAfter))
        }
        #expect(kind(502) == .serverDown)
        #expect(kind(503) == .serverDown)
        #expect(kind(504) == .serverDown)
        #expect(kind(500) == .serverError)
        #expect(kind(404) == .notFound)
        #expect(kind(429, retryAfter: 7) == .rateLimited(retryAfter: 7))
        #expect(kind(400) == .rejected("m"))
        #expect(kind(409) == .rejected("m"))
        // Only what can pass is retried.
        #expect(kind(503).isRetryable)
        #expect(kind(429).isRetryable)
        #expect(!kind(400).isRetryable)
        #expect(!kind(404).isRetryable)
        #expect(!kind(500).isRetryable)
    }

    @Test func anAnswerThatDoesNotDecodeIsTheServersFault() {
        let error = DecodingError.dataCorrupted(.init(codingPath: [], debugDescription: "x"))
        #expect(APIError.classify(error) == .serverError)
    }

    @Test func retryAfterFromTheHeaderOrTheText() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        #expect(APIError.retryAfter(header: "12", message: nil) == 12)
        #expect(APIError.retryAfter(header: "Fri, 15 Jan 2027 08:00:30 GMT", message: nil, now: now) == 30)
        #expect(APIError.retryAfter(header: nil, message: "too many requests, try again in 9 seconds", now: now) == 9)
        #expect(APIError.retryAfter(header: nil, message: "try again in 1 second") == 1)
        // The header wins over the text.
        #expect(APIError.retryAfter(header: "3", message: "try again in 9 seconds") == 3)
        #expect(APIError.retryAfter(header: nil, message: "already reported a few minutes ago") == nil)
    }
}

struct SSERetryTests {
    @Test func theParserKeepsTheServersRetry() {
        var parser = SSEParser()
        #expect(parser.feed("retry: 5000") == nil)
        #expect(parser.retry == 5000)
        _ = parser.feed("retry: soon")
        #expect(parser.retry == 5000)
        #expect(SSEEvent(name: SSEEvent.retryName, data: "5000").retrySeconds == 5)
        #expect(SSEEvent(name: "live", data: "5000").retrySeconds == nil)
    }
}

struct RetryWakeTests {
    @Test func aWakeEndsTheWaitEarly() async throws {
        let wake = RetryWake()
        let started = Date.now
        let waiting = Task { try await wake.sleep(60) }
        while wake.waiting == 0 { try await Task.sleep(for: .milliseconds(5)) }
        wake.wake()
        #expect(try await waiting.value == true)
        #expect(Date.now.timeIntervalSince(started) < 5)
    }

    @Test func aWaitRunsOutByItself() async throws {
        let wake = RetryWake()
        #expect(try await wake.sleep(0.05) == false)
        #expect(wake.waiting == 0)
    }

    @Test func cancellingEndsTheWait() async {
        let wake = RetryWake()
        let waiting = Task { try await wake.sleep(60) }
        try? await Task.sleep(for: .milliseconds(20))
        waiting.cancel()
        await #expect(throws: CancellationError.self) { try await waiting.value }
        #expect(wake.waiting == 0)
    }
}

struct ConnectionTrackerTests {
    @Test func theServerAnsweringAgainAfterTroubleWakesTheRetries() {
        var c = ConnectionTracker()
        #expect(c.report(.failed(.serverDown)) == false)
        #expect(c.report(.failed(.serverDown)) == false)
        #expect(c.state == .serverTrouble)
        // The strip clears, and the waiting retries go at once (build 86: Network now sat out a 35 s countdown).
        #expect(c.report(.answered) == true)
        #expect(c.state == .online)
        // Already online: an answer wakes nothing.
        #expect(c.report(.answered) == false)
    }

    @Test func anAnswerAfterOfflineWakesTooAndOneLostAnswerSaysNoConnection() {
        var c = ConnectionTracker()
        #expect(c.report(.failed(.offline)) == false)
        #expect(c.state == .offline)
        #expect(c.report(.answered) == true)
        _ = c.report(.failed(.timeout))
        #expect(c.state == .offline)
        _ = c.report(.failed(.timeout))
        #expect(c.state == .serverTrouble)
    }

    @Test func thePathComingBackWakesAndForgetsTheOldFailures() {
        var c = ConnectionTracker()
        _ = c.report(.failed(.serverDown))
        _ = c.report(.failed(.serverDown))
        #expect(c.pathChanged(satisfied: false) == false)
        #expect(c.state == .offline)
        #expect(c.pathChanged(satisfied: true) == true)
        #expect(c.state == .online)
        #expect(c.pathChanged(satisfied: true) == false)
    }
}

struct FailureAdviceTests {
    @Test func onlyOfflineSaysCheckYourConnection() {
        #expect(APIError.adviceKey(.offline) == "failure.checkConnection")
        #expect(APIError.adviceKey(.serverDown) == "failure.serverNotAnswering")
        #expect(APIError.adviceKey(.timeout) == "failure.serverNotAnswering")
        #expect(APIError.adviceKey(.rateLimited(retryAfter: 5)) == "failure.serverNotAnswering")
        #expect(APIError.adviceKey(.serverError) == "failure.serverFault")
        #expect(APIError.adviceKey(nil) == "failure.tryAgain")
        #expect(APIError.adviceKey(.rejected("no")) == "failure.tryAgain")
    }

    @MainActor @Test func everyAdviceIsInTheCatalogInEveryLanguage() {
        let keys = ["failure.checkConnection", "failure.serverNotAnswering", "failure.serverFault", "failure.tryAgain"]
        for language in Language.knownCases {
            let l10n = L10n(language: language)
            for key in keys { #expect(l10n.t(key) != key, "\(key) in \(language.rawValue)") }
        }
    }
}

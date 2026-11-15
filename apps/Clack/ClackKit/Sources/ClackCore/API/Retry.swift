//
//  Retry.swift
//  Clack
//

import Foundation
import Observation
import os

/// How long to wait before asking again after a failure: exponential (1 s, 2 s, 4 s … up to a cap) with full jitter, so
/// phones that lost the server at the same moment don't all come back at the same moment. An answer resets it. A wait
/// the server named (a 429's Retry-After) is used as it is, in place of the computed one.
public nonisolated struct Backoff: Sendable, Equatable {
    public var base: TimeInterval
    public var factor: Double
    public var cap: TimeInterval
    /// Failures in a row since the last answer.
    public private(set) var failures = 0

    /// The shortest wait, so a jittered draw near zero doesn't ask again in the same instant.
    public static let shortest: TimeInterval = 0.2
    /// The longest Retry-After believed (a wrong header shouldn't park a screen for an hour).
    public static let longestRetryAfter: TimeInterval = 600

    public init(base: TimeInterval = 1, factor: Double = 2, cap: TimeInterval = 30) {
        self.base = base
        self.factor = factor
        self.cap = cap
    }

    /// The most the wait can be after this many failures in a row: base, base × factor, … never above the cap.
    public func ceiling(after failures: Int) -> TimeInterval {
        guard failures > 0 else { return 0 }
        return min(cap, base * pow(factor, Double(failures - 1)))
    }

    /// Counts a failure and gives the wait before the next try: a random draw between nothing and the ceiling (full
    /// jitter), at least `atLeast` (an SSE stream's `retry:`); or the server's Retry-After when it named one.
    public mutating func next(
        retryAfter: TimeInterval? = nil, atLeast floor: TimeInterval = 0,
        random: (ClosedRange<Double>) -> Double = { Double.random(in: $0) }
    ) -> TimeInterval {
        failures += 1
        if let retryAfter, retryAfter > 0 { return min(retryAfter, Self.longestRetryAfter) }
        return max(random(0...ceiling(after: failures)), floor, Self.shortest)
    }

    /// An answer came: the next failure starts from the base again.
    public mutating func reset() { failures = 0 }
}

/// When and how often a failed request is asked again. Only failures that can pass are retried (no connection, a
/// timeout, the server down, too many requests); a refusal (another 4xx) never is.
public nonisolated struct RetryPolicy: Sendable, Equatable {
    /// Tries in all, the first included; nil never gives up (a poll or a stream, while it runs).
    public var tries: Int?
    public var base: TimeInterval
    public var factor: Double
    public var cap: TimeInterval
    /// A poll's pace while answers come; failures back off from `base` instead, up to `cap`.
    public var every: TimeInterval?

    public init(tries: Int?, base: TimeInterval = 1, factor: Double = 2, cap: TimeInterval = 30, every: TimeInterval? = nil) {
        self.tries = tries
        self.base = base
        self.factor = factor
        self.cap = cap
        self.every = every
    }

    /// A read the person is waiting for: up to five tries, 1 s, 2 s, 4 s, 8 s apart (jittered).
    public static let read = RetryPolicy(tries: 5)
    /// Asked once: writes (a POST that went through but whose answer was lost must not be sent twice by itself), and
    /// loops that back off themselves.
    public static let none = RetryPolicy(tries: 1)
    /// A live stream: reconnects for as long as it's wanted, 1 s, 2 s, 4 s … 30 s apart.
    public static let stream = RetryPolicy(tries: nil)

    /// A poll: every `every` seconds while answers come; after a failure 2 s, 4 s … up to two minutes, never giving up.
    public static func poll(every: TimeInterval) -> RetryPolicy {
        RetryPolicy(tries: nil, base: 2, cap: 120, every: every)
    }

    public var backoff: Backoff { Backoff(base: base, factor: factor, cap: cap) }
}

/// Where a retrying piece of work stands, for the screen showing it: nothing wrong, waiting to try again (and when),
/// or given up (and why).
public nonisolated enum RetryStatus: Sendable, Equatable {
    case idle
    case retrying(attempt: Int, next: Date, kind: APIError.Kind)
    case gaveUp(APIError.Kind)

    /// What went wrong, while something did.
    public var kind: APIError.Kind? {
        switch self {
        case .idle: nil
        case .retrying(_, _, let kind), .gaveUp(let kind): kind
        }
    }

    /// When the next try is due, while one is.
    public var next: Date? {
        if case .retrying(_, let next, _) = self { return next }
        return nil
    }
}

/// One loop's retrying: its policy, its backoff and where it stands. A poll or a stream keeps one for as long as it
/// runs; `succeeded` and `failed` say how long to wait next.
public nonisolated struct Retrier: Sendable, Equatable {
    public let policy: RetryPolicy
    public private(set) var backoff: Backoff
    public private(set) var status: RetryStatus = .idle
    /// The shortest wait the server asked for (an SSE stream's `retry:`), if it did.
    public var serverHint: TimeInterval?

    public init(_ policy: RetryPolicy) {
        self.policy = policy
        self.backoff = policy.backoff
    }

    /// An answer came: failures are forgotten. The wait before the next healthy ask (a poll's pace), if there is one.
    @discardableResult
    public mutating func succeeded() -> TimeInterval? {
        backoff.reset()
        status = .idle
        return policy.every
    }

    /// A failure: the wait before asking again, or nil to stop (cancelled, or the tries are used up). A failure that
    /// asking again can't fix (a refusal, a missing train) stops a one-off read; a poll keeps its healthy pace.
    public mutating func failed(_ error: any Error, now: Date = .now, random: (ClosedRange<Double>) -> Double = { Double.random(in: $0) }) -> TimeInterval? {
        failed(APIError.classify(error), now: now, random: random)
    }

    public mutating func failed(_ kind: APIError.Kind, now: Date = .now, random: (ClosedRange<Double>) -> Double = { Double.random(in: $0) }) -> TimeInterval? {
        if kind == .cancelled { return nil }
        guard kind.isRetryable else {
            status = .gaveUp(kind)
            return policy.every
        }
        if let tries = policy.tries, backoff.failures + 1 >= tries {
            status = .gaveUp(kind)
            return nil
        }
        let delay = backoff.next(retryAfter: kind.retryAfter, atLeast: serverHint ?? 0, random: random)
        status = .retrying(attempt: backoff.failures, next: now.addingTimeInterval(delay), kind: kind)
        return delay
    }

    /// Starts over (the person pressed Try again).
    public mutating func reset() {
        backoff.reset()
        status = .idle
    }
}

/// The policy and the progress reporting a piece of work runs under, read by `APIClient.request` (task-local, so a
/// screen can set them around a call without every endpoint taking them).
public nonisolated enum RetryContext {
    /// Overrides the method's default policy (a loop that backs off itself asks once: `.none`).
    @TaskLocal public static var policy: RetryPolicy?
    /// Told before every wait and when a request gives up, so the screen can say "Trying again in 4 s".
    @TaskLocal public static var observer: (@Sendable (RetryStatus) -> Void)?
}

extension RetryPolicy {
    /// Runs `body` with every request in it under this policy.
    public func applying<T>(_ body: () async throws -> T) async rethrows -> T {
        try await RetryContext.$policy.withValue(self) { try await body() }
    }
}

/// Runs `body`, telling `observer` where its requests' retries stand.
public nonisolated func observingRetries<T>(_ observer: @escaping @Sendable (RetryStatus) -> Void, _ body: () async throws -> T) async rethrows -> T {
    try await RetryContext.$observer.withValue(observer) { try await body() }
}

/// Where one screen's retries stand, for its loading and error views to read ("Trying again in 4 s"). A loop that backs
/// off itself sets it from its `Retrier`; a one-off read runs under `run`, which hears `APIClient.request`'s retries.
@MainActor
@Observable
public final class RetryTracker {
    public private(set) var status: RetryStatus = .idle

    public init() {}

    public func set(_ status: RetryStatus) {
        if status != self.status { self.status = status }
    }

    /// Runs `body`, with the retries of the requests in it said here; idle again once it answers or is cancelled
    /// (a failure keeps `gaveUp` for the screen to show).
    public func run<T>(_ body: () async throws -> T) async throws -> T {
        set(.idle)
        let observer: @Sendable (RetryStatus) -> Void = { [weak self] status in
            Task { @MainActor in self?.set(status) }
        }
        do {
            let value = try await observingRetries(observer, body)
            set(.idle)
            return value
        } catch {
            if APIError.classify(error) == .cancelled { set(.idle) }
            throw error
        }
    }
}

extension RetryWake {
    /// A loop's wait: `seconds`, or less when the connection comes back or the app comes to the front. False when the
    /// task was cancelled (the loop should stop).
    public static func pause(_ seconds: TimeInterval) async -> Bool {
        do {
            try await shared.sleep(seconds)
            return true
        } catch {
            return false
        }
    }
}

/// Wakes the retries that are waiting, at once: the phone's connection came back or the app came to the front, so
/// there's no reason to sit out the rest of a backoff.
public nonisolated final class RetryWake: Sendable {
    public static let shared = RetryWake()

    private struct Waiter {
        let continuation: CheckedContinuation<Bool, Never>
        var timer: Task<Void, Never>?
    }

    private let waiters = OSAllocatedUnfairLock<[UUID: Waiter]>(initialState: [:])

    public init() {}

    /// Waits `seconds`, or until `wake()`. True when woken early. Throws when the task is cancelled.
    @discardableResult
    public func sleep(_ seconds: TimeInterval) async throws -> Bool {
        try Task.checkCancellation()
        let id = UUID()
        let woken = await withTaskCancellationHandler {
            await withCheckedContinuation { (continuation: CheckedContinuation<Bool, Never>) in
                waiters.withLock { $0[id] = Waiter(continuation: continuation) }
                // Cancelled between the check above and here: the handler found nothing to resume.
                if Task.isCancelled {
                    resume(id, woken: false)
                    return
                }
                let timer = Task { [weak self] in
                    try? await Task.sleep(for: .seconds(max(0, seconds)))
                    self?.resume(id, woken: false)
                }
                let stored = waiters.withLock { all -> Bool in
                    guard all[id] != nil else { return false }
                    all[id]?.timer = timer
                    return true
                }
                if !stored { timer.cancel() }
            }
        } onCancel: {
            resume(id, woken: false)
        }
        try Task.checkCancellation()
        return woken
    }

    /// Every waiting retry goes now.
    public func wake() {
        let all = waiters.withLock { all -> [Waiter] in
            let list = Array(all.values)
            all = [:]
            return list
        }
        for waiter in all {
            waiter.timer?.cancel()
            waiter.continuation.resume(returning: true)
        }
    }

    /// How many retries are waiting now.
    public var waiting: Int { waiters.withLock { $0.count } }

    private func resume(_ id: UUID, woken: Bool) {
        guard let waiter = waiters.withLock({ $0.removeValue(forKey: id) }) else { return }
        waiter.timer?.cancel()
        waiter.continuation.resume(returning: woken)
    }
}

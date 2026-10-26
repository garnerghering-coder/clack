//
//  AddTrainHistoryTests.swift
//  ClackTests
//

import ClackCore
import Foundation
import Testing
@testable import Clack

/// Answers the app's requests from a closure, counting searches, so the Add sheet's model runs without a network.
final class HistoryStub: URLProtocol, @unchecked Sendable {
    nonisolated(unsafe) static var searches = 0
    nonisolated(unsafe) static var prepared: [String] = []
    /// How many searches still answer "loading" before the day is in.
    nonisolated(unsafe) static var loadingFor = 0

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        let url = request.url!
        let body: String
        if url.path.hasSuffix("/history/prepare") {
            HistoryStub.prepared.append(URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems?.first { $0.name == "date" }?.value ?? "")
            body = #"{"sweden":"loading"}"#
        } else {
            HistoryStub.searches += 1
            let loading = HistoryStub.searches <= HistoryStub.loadingFor
            body = """
            {"date":"2025-03-10","interpretation":{"operator":null,"trainNumber":"421","from":null,"to":null,"typing":null},
             "suggestions":[],"results":[],"connections":null,"outsideTimetable":\(loading),"history":"\(loading ? "loading" : "ready")"}
            """
        }
        client?.urlProtocol(self, didReceive: HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data(body.utf8))
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}

    static var client: APIClient {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [HistoryStub.self]
        return APIClient(base: URL(string: "http://localhost:3001")!, userID: "11111111-1111-4111-8111-111111111111", session: URLSession(configuration: configuration), cache: nil, reachability: nil)
    }
}

@MainActor
@Suite(.serialized)
struct AddTrainHistoryTests {
    /// The sheet runs these two tasks: the search on every key change, and the wait while an old day is fetched.
    private func runLikeTheSheet(_ model: AddTrainModel, _ client: APIClient, seconds: Double) async {
        let deadline = Date.now.addingTimeInterval(seconds)
        var lastKey = ""
        let waiting = Task { await model.waitForHistory() }
        while Date.now < deadline {
            if model.searchKey != lastKey {
                lastKey = model.searchKey
                await model.runSearch(client)
            }
            try? await Task.sleep(for: .milliseconds(100))
        }
        waiting.cancel()
    }

    @Test func keepsAskingWhileAnOldDayIsFetchedAndStopsWhenItsIn() async {
        HistoryStub.searches = 0
        HistoryStub.loadingFor = 3
        let model = AddTrainModel()
        model.date = "2025-03-10"
        model.query = "421"
        let client = HistoryStub.client
        await model.runSearch(client)
        #expect(model.response?.history == "loading")
        await runLikeTheSheet(model, client, seconds: 9)
        // Asked again until the answer changed (not just once, as before), then stopped.
        #expect(HistoryStub.searches == 4)
        #expect(model.response?.history == "ready")
    }

    @Test func startsFetchingAnOldDayAsSoonAsItIsPicked() async {
        HistoryStub.prepared = []
        let model = AddTrainModel()
        await model.prepareHistory(HistoryStub.client)
        model.date = "2025-03-10"
        await model.prepareHistory(HistoryStub.client)
        // Today needs nothing; the old day is asked for straight away.
        #expect(HistoryStub.prepared == ["2025-03-10"])
    }
}

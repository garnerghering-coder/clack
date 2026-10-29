//
//  AddTrainPagingTests.swift
//  ClackTests
//

import ClackCore
import Foundation
import Testing
@testable import Clack

/// Serves planner pages: a whole day when no `after` is given (one journey at 20:00), else six hours from `after`
/// with one journey an hour in, plus the day's 20:00 journey again (to see that pages are merged without repeats).
final class PagingStub: URLProtocol, @unchecked Sendable {
    nonisolated(unsafe) static var requests: [[String: String]] = []
    /// 2026-11-05 00:00 in Stockholm (CET), the day searched.
    static let dayStart = 1793833200000.0

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        let url = request.url!
        let q = Dictionary((URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []).map { ($0.name, $0.value ?? "") }, uniquingKeysWith: { a, _ in a })
        PagingStub.requests.append(q)
        let day = PagingStub.dayStart
        let evening = journey("t1", dep: day + 20 * 3_600_000)
        let body: String
        if let after = q["after"].flatMap(Double.init) {
            let hours = Double(q["hours"] ?? "6") ?? 6
            body = page([journey("t2", dep: after + 3_600_000), evening], start: after, end: after + hours * 3_600_000)
        } else {
            body = page([evening], start: day, end: day + 86_400_000)
        }
        client?.urlProtocol(self, didReceive: HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data(body.utf8))
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}

    private func page(_ journeys: [String], start: Double, end: Double) -> String {
        """
        {"date":"2026-11-05","interpretation":{"operator":null,"trainNumber":null,"from":{"id":"740000001","name":"Stockholm C","country":"SE"},"to":{"id":"740000002","name":"Göteborg C","country":"SE"},"typing":null},
         "suggestions":[],"results":[],"connections":null,"outsideTimetable":false,"history":null,
         "journeys":[\(journeys.joined(separator: ","))],"window":{"start":\(Int64(start)),"end":\(Int64(end))}}
        """
    }

    private func journey(_ key: String, dep: Double) -> String {
        let arr = dep + 200 * 60_000
        func stop(_ seq: Int, _ id: String, _ name: String, _ t: Double) -> String {
            #"{"seq":\#(seq),"stationId":"\#(id)","name":"\#(name)","code":null,"country":"SE","tz":"Europe/Stockholm","time":\#(Int64(t))}"#
        }
        return """
        {"legs":[{"key":"\(key)","serviceDate":"2026-11-05","trainNumber":"\(key)","operatorId":"sj","category":"X2000","product":"express","trainType":null,"routeName":null,
          "from":\(stop(1, "740000001", "Stockholm C", dep)),"to":\(stop(9, "740000002", "Göteborg C", arr)),"durationMin":200,"stopsBetween":3,"alsoKnownAs":[]}],
         "changes":[],"dep":\(Int64(dep)),"arr":\(Int64(arr)),"durationMin":200,"fastest":true}
        """
    }

    static var client: APIClient {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [PagingStub.self]
        return APIClient(base: URL(string: "http://localhost:3001")!, userID: "11111111-1111-4111-8111-111111111111", session: URLSession(configuration: configuration), cache: nil, reachability: nil)
    }
}

@MainActor
@Suite(.serialized)
struct AddTrainPagingTests {
    /// A day other than today is asked for whole; Show later asks for six hours from the window's end, and the
    /// answers are merged by departure without repeats; the first journey on the next day gets a day line.
    @Test func pagesLaterAcrossMidnightAndMergesWithoutRepeats() async {
        PagingStub.requests = []
        let model = AddTrainModel()
        model.date = "2026-11-05"
        model.query = "Stockholm → Göteborg"
        let client = PagingStub.client
        await model.runSearch(client)
        #expect(model.journeys?.map(\.legs.first?.key) == ["t1"])
        #expect(model.window?.start == PagingStub.dayStart)
        // The planner is asked for the most changes it does; the filter picks from that.
        #expect(PagingStub.requests.first?["changes"] == "5")
        #expect(PagingStub.requests.first?["after"] == nil)

        await model.showLaterJourneys(client)
        let dayEnd = PagingStub.dayStart + 86_400_000
        #expect(PagingStub.requests.last?["after"] == String(Int64(dayEnd)))
        #expect(PagingStub.requests.last?["hours"] == "6")
        #expect(model.window?.end == dayEnd + 6 * 3_600_000)
        let list = model.journeys ?? []
        #expect(list.map(\.legs.first?.key) == ["t1", "t2"])
        #expect(model.laterEmpty == false)
        // 20:00 on the day searched: no line; 01:00 the next day: its date.
        #expect(model.daySeparator(before: list[0], previous: nil, language: .en) == nil)
        #expect(model.daySeparator(before: list[1], previous: list[0], language: .en) == "Fri 6 Nov")
    }

    @Test func filterKeepsJourneysWithinTheChangesAsked() {
        let model = AddTrainModel()
        #expect(model.maxChanges == AddTrainModel.defaultMaxChanges)
        #expect(AddTrainModel.maxChangesLimit == 5)
    }
}

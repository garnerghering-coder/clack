//
//  StationMapLink.swift
//  Clack
//

import Foundation

/// The Layover Guide's inputs from a connection (the web's `/stations/:id/map?from=&to=&arr=&dep=&a=&b=&xa=&xb=&live=`).
public nonisolated struct StationMapLink: Hashable, Sendable {
    public var stationId: String
    public var from: String?
    public var to: String?
    public var arrival: Double?
    public var departure: Double?
    public var operatorA: String?
    public var operatorB: String?
    public var canceledA = false
    public var canceledB = false
    public var live = false

    public init(
        stationId: String, from: String? = nil, to: String? = nil, arrival: Double? = nil, departure: Double? = nil,
        operatorA: String? = nil, operatorB: String? = nil, canceledA: Bool = false, canceledB: Bool = false, live: Bool = false
    ) {
        self.stationId = stationId
        self.from = from
        self.to = to
        self.arrival = arrival
        self.departure = departure
        self.operatorA = operatorA
        self.operatorB = operatorB
        self.canceledA = canceledA
        self.canceledB = canceledB
        self.live = live
    }
}

//
//  WalletPass.swift
//  Clack
//

import Foundation

/// What the server needs to sign an Apple Wallet pass for a kept ticket (`POST /api/wallet/pass`, a test tool for now:
/// docs/TICKET_WALLET_FINDINGS.md). The ticket's code goes as its exact bytes (base64 in JSON); the server signs the
/// pass and keeps none of it. No name or booking number is sent.
public nonisolated struct WalletPassBody: Encodable, Sendable, Equatable {
    public var issuer: TicketTrain.Issuer
    public var operatorName: String?
    public var trainNumber: String?
    public var from: String
    public var to: String
    /// Milliseconds since 1970, the timetable's departure and arrival.
    public var depAt: Double
    public var arrAt: Double?
    public var coach: String?
    public var seat: String?
    public var format: TicketBarcode.Format
    /// The code's bytes; encoded as base64.
    public var barcode: Data
    /// The pass's labels: "en" or "sv".
    public var lang: String

    public init(issuer: TicketTrain.Issuer, operatorName: String?, trainNumber: String?, from: String, to: String, depAt: Double, arrAt: Double?, coach: String?, seat: String?, barcode: TicketBarcode, lang: String) {
        self.issuer = issuer
        self.operatorName = operatorName
        self.trainNumber = trainNumber
        self.from = from
        self.to = to
        self.depAt = depAt
        self.arrAt = arrAt
        self.coach = coach
        self.seat = seat
        self.format = barcode.format
        self.barcode = barcode.payload
        self.lang = lang == "sv" ? "sv" : "en"
    }
}

extension APIClient {
    /// A signed .pkpass for a kept ticket, to hand to PassKit.
    public func walletPass(_ body: WalletPassBody) async throws -> Data {
        try await request("POST", ["wallet", "pass"], body: body)
    }
}

//
//  Config.swift
//  Clack
//

import Foundation

nonisolated enum Config {
    /// Where the Clack server is. Debug in the simulator: the server on this Mac. Debug on a phone: the Mac by
    /// name, through Vite's proxy (`npm run dev:phone`). Release: the hosted server (docs/IOS.md step 9).
    static let apiBase: URL = {
        #if DEBUG
        #if targetEnvironment(simulator)
        return URL(string: "http://localhost:3001")!
        #else
        return URL(string: "http://\(macHostName).local:5173")!
        #endif
        #else
        return URL(string: "https://REPLACE-WITH-YOUR-SERVER")!
        #endif
    }()
    /// The Mac's local name: System Settings > General > Sharing > Local hostname, without ".local".
    static let macHostName = "Garners-MacBook-Air"
    /// Operators' logos are trademarks; Garner has the operators' approval to use them (docs/APP_STORE.md, 5.2.1).
    static let showOperatorLogos = true
    /// Shown on the Privacy screen when set (docs/APP_STORE.md, 1.5).
    static let supportEmail: String? = nil
}

//
//  Config.swift
//  Clack
//

import Foundation

public nonisolated enum Config {
    /// Where the Clack server is: the hosted one, on the internet, for every build on a phone. Only a debug build in the
    /// simulator uses the server running on this Mac (`npm run dev`), because that is where it is being worked on.
    /// `-apiBase https://...` as a launch argument points a debug build anywhere else.
    public static let apiBase: URL = {
        let hosted = URL(string: "https://getclack.app")!
        #if DEBUG
        if let override = UserDefaults.standard.string(forKey: "apiBase"), let url = URL(string: override) { return url }
        #if targetEnvironment(simulator)
        return URL(string: "http://localhost:3001")!
        #else
        return hosted
        #endif
        #else
        return hosted
        #endif
    }()
    /// The address of the links people share (`https://<host>/j/<token>`): the hosted server's own name, and its older
    /// free name, which keeps working for links and builds made before getclack.app. A link on another host is not ours
    /// and opens nothing.
    public static let shareHost = "getclack.app"
    public static let shareHosts: Set<String> = ["getclack.app", "www.getclack.app", "clack-garner.duckdns.org"]
    /// Operators' logos are trademarks; Garner has the operators' approval to use them (docs/APP_STORE.md, 5.2.1).
    public static let showOperatorLogos = true
    /// Shown on the Privacy screen (docs/APP_STORE.md, 1.5). The owner chose to publish it. It is displayed only: it must
    /// never go into a request, a header or a user agent (CLAUDE.md).
    public static let supportEmail: String? = "garnerghering@gmail.com"
}

//
//  Config.swift
//  Clack
//

import Foundation

public nonisolated enum Config {
    /// Where the Clack server is: the hosted one, on the internet, for every build on a phone. Only a debug build in the
    /// simulator uses the server running on this Mac (`npm run dev`), because that is where it is being worked on, and
    /// only when it answers; otherwise it uses the hosted one, so the app still opens without the Mac's server.
    /// `-apiBase https://...` as a launch argument points a debug build anywhere else.
    public static let apiBase: URL = {
        let hosted = URL(string: "https://getclack.app")!
        #if DEBUG
        if let override = UserDefaults.standard.string(forKey: "apiBase"), let url = URL(string: override) { return url }
        #if targetEnvironment(simulator)
        let local = URL(string: "http://localhost:3001")!
        return answers(local) ? local : hosted
        #else
        return hosted
        #endif
        #else
        return hosted
        #endif
    }()

    #if DEBUG && targetEnvironment(simulator)
    /// Whether a server answers `/api/health` at `base`, waiting at most a second. Asked once, when `apiBase` is first
    /// read; a server that isn't running refuses at once, so this rarely waits at all.
    private static func answers(_ base: URL) -> Bool {
        var request = URLRequest(url: base.appendingPathComponent("api/health"))
        request.timeoutInterval = 1
        let done = DispatchSemaphore(value: 0)
        nonisolated(unsafe) var ok = false
        URLSession(configuration: .ephemeral).dataTask(with: request) { _, response, _ in
            ok = (response as? HTTPURLResponse)?.statusCode == 200
            done.signal()
        }.resume()
        _ = done.wait(timeout: .now() + 1.5)
        return ok
    }
    #endif
    /// "Buy ticket with Omio" opens Omio's home page through Clack's own affiliate link (Impact), made once in the Impact
    /// dashboard (owner, 2026-10-26). It does not fill in a journey; that can come later.
    public static let omioURL = URL(string: "https://omio.sjv.io/DWG092")!
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

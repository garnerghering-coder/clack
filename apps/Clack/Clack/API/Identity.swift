//
//  Identity.swift
//  Clack
//

import Foundation
import Security

/// The phone's id: a random UUID v4 in the Keychain, sent as `X-Clack-User` (docs/SWIFT_PORT.md B4).
/// There is no sign-in; the Keychain keeps the id across reinstalls.
nonisolated enum Identity {
    private static let service = "clack.user"
    private static let account = "id"

    /// The stored id, or a new one saved on first launch.
    static func current() -> String {
        if let existing = load() { return existing }
        let fresh = UUID().uuidString.lowercased()
        save(fresh)
        return fresh
    }

    /// Forgets the id ("Delete my data"): the next `current()` makes a new one.
    static func delete() {
        SecItemDelete(baseQuery() as CFDictionary)
    }

    private static func baseQuery() -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
    }

    private static func load() -> String? {
        var query = baseQuery()
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data,
              let id = String(data: data, encoding: .utf8) else { return nil }
        return id
    }

    private static func save(_ id: String) {
        var query = baseQuery()
        query[kSecValueData as String] = Data(id.utf8)
        query[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        SecItemAdd(query as CFDictionary, nil)
    }
}

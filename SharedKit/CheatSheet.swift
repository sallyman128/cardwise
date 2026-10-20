import Foundation
import Security

/// The best card for each everyday category, precomputed by the app so the widget
/// (and later a Watch app) can show it without running the recommendation engine.
nonisolated struct CheatSheet: Codable, Hashable, Sendable {
    struct Row: Codable, Hashable, Sendable, Identifiable {
        /// SpendCategory raw value.
        let id: String
        let title: String
        let symbol: String
        let cardName: String
        /// Short rate, e.g. "4x" or "3%".
        let rate: String
        let colorHex: String
    }

    let goalTitle: String
    let rows: [Row]

    static let placeholder = CheatSheet(goalTitle: "Most travel value", rows: [
        Row(id: "dining", title: "Dining", symbol: "fork.knife", cardName: "Gold Card", rate: "4x", colorHex: "#B8975A"),
        Row(id: "groceries", title: "Groceries", symbol: "cart", cardName: "Gold Card", rate: "4x", colorHex: "#B8975A"),
        Row(id: "gas", title: "Gas", symbol: "fuelpump", cardName: "Double Cash", rate: "2x", colorHex: "#5A6F80"),
        Row(id: "travel", title: "Travel", symbol: "suitcase", cardName: "Sapphire Preferred", rate: "2x", colorHex: "#1C3A6B"),
        Row(id: "onlineShopping", title: "Online", symbol: "bag", cardName: "Double Cash", rate: "2x", colorHex: "#5A6F80"),
        Row(id: "drugstores", title: "Drugstores", symbol: "cross.case", cardName: "Double Cash", rate: "2x", colorHex: "#5A6F80"),
        Row(id: "streaming", title: "Streaming", symbol: "play.tv", cardName: "Sapphire Preferred", rate: "3x", colorHex: "#1C3A6B"),
        Row(id: "other", title: "Everything else", symbol: "creditcard", cardName: "Double Cash", rate: "2x", colorHex: "#5A6F80"),
    ])

    // MARK: - Storage

    // Stored in a keychain group shared by the app and the widget. App Groups would be the usual
    // choice, but they need setup in Xcode for free developer accounts; team-prefixed keychain
    // groups are allowed by every provisioning profile.

    /// Must match `keychain-access-groups` in both targets' entitlements.
    static let accessGroupSuffix = "com.salmaanali.CardWise.shared"
    private static let service = "CardWise"
    private static let account = "cheatSheet"

    /// The team prefix this binary was signed with, read from a keychain item it creates.
    /// Nil in an unsigned build, where the default access group is used instead.
    private static let accessGroup: String? = {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "CardWise.teamProbe",
            kSecAttrAccount as String: "probe",
            kSecReturnAttributes as String: true,
        ]
        var result: AnyObject?
        var status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound {
            var add = query
            add.removeValue(forKey: kSecReturnAttributes as String)
            add[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
            SecItemAdd(add as CFDictionary, nil)
            status = SecItemCopyMatching(query as CFDictionary, &result)
        }
        guard status == errSecSuccess,
              let group = (result as? [String: Any])?[kSecAttrAccessGroup as String] as? String,
              let prefix = group.split(separator: ".").first else { return nil }
        return "\(prefix).\(accessGroupSuffix)"
    }()

    private static func baseQuery() -> [String: Any] {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        if let accessGroup { query[kSecAttrAccessGroup as String] = accessGroup }
        return query
    }

    static func load() -> CheatSheet? {
        var query = baseQuery()
        query[kSecReturnData as String] = true
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else { return nil }
        return try? JSONDecoder().decode(CheatSheet.self, from: data)
    }

    func save() {
        guard let data = try? JSONEncoder().encode(self) else { return }
        let query = Self.baseQuery()
        let update: [String: Any] = [kSecValueData as String: data]
        if SecItemUpdate(query as CFDictionary, update as CFDictionary) == errSecItemNotFound {
            var add = query
            add[kSecValueData as String] = data
            // The widget may refresh while the phone is locked.
            add[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
            SecItemAdd(add as CFDictionary, nil)
        }
    }
}

import Foundation

/// A store or service whose purchases code to a known category.
nonisolated struct Merchant: Codable, Identifiable, Hashable, Sendable {
    let id: String
    let name: String
    let aliases: [String]?
    let category: SpendCategory
    /// Shown in quick picks on the Search screen.
    let online: Bool
    /// Caveats about how purchases here usually code, e.g. "Usually not coded as groceries".
    let note: String?
}

/// Looks merchants up by search query or by the name of a place from Apple Maps.
nonisolated struct MerchantDirectory: Sendable {
    let merchants: [Merchant]
    private let byID: [String: Merchant]

    init(merchants: [Merchant]) {
        self.merchants = merchants
        self.byID = Dictionary(merchants.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
    }

    func merchant(id: String) -> Merchant? {
        byID[id]
    }

    /// Merchants whose name or alias matches what the user typed, best matches first.
    func search(_ query: String) -> [Merchant] {
        let needle = Self.normalize(query)
        guard !needle.isEmpty else { return [] }

        let scored: [(Merchant, Int)] = merchants.compactMap { merchant in
            let best = Self.names(of: merchant).map { name -> Int in
                if name == needle { return 3 }
                if name.hasPrefix(needle) { return 2 }
                if name.split(separator: " ").contains(where: { $0.hasPrefix(needle) }) { return 1 }
                return 0
            }.max() ?? 0
            return best > 0 ? (merchant, best) : nil
        }
        return scored
            .sorted { $0.1 != $1.1 ? $0.1 > $1.1 : $0.0.name < $1.0.name }
            .map(\.0)
    }

    /// The merchant a place name refers to, e.g. "Costco Wholesale" → Costco.
    /// Only matches at the start of the name, so "Big Apple Pizza" isn't Apple.
    func match(placeName: String) -> Merchant? {
        var name = Self.normalize(placeName)
        if name.hasPrefix("the ") { name.removeFirst(4) }

        var best: (merchant: Merchant, length: Int)?
        for merchant in merchants {
            for alias in Self.names(of: merchant) {
                let matches = name == alias || name.hasPrefix(alias + " ")
                if matches, alias.count > (best?.length ?? 0) {
                    best = (merchant, alias.count)
                }
            }
        }
        return best?.merchant
    }

    private static func names(of merchant: Merchant) -> [String] {
        ([merchant.name] + (merchant.aliases ?? [])).map { name in
            let normalized = normalize(name)
            return normalized.hasPrefix("the ") ? String(normalized.dropFirst(4)) : normalized
        }
    }

    /// Lowercased, accents and punctuation removed, "&" spelled out, spaces collapsed.
    static func normalize(_ text: String) -> String {
        let folded = text
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            .replacingOccurrences(of: "&", with: " and ")
            .replacingOccurrences(of: "'", with: "")
            .replacingOccurrences(of: "’", with: "")
        let cleaned = folded.unicodeScalars.map { CharacterSet.alphanumerics.contains($0) ? Character($0) : " " }
        return String(cleaned).split(separator: " ").joined(separator: " ")
    }
}

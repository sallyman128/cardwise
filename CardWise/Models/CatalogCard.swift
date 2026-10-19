import Foundation

/// The card list the app ships with and refreshes from the hosted copy of `cards.json`.
nonisolated struct CardCatalog: Codable, Sendable {
    /// Bumped only when the file format changes in a way older app versions can't read.
    let schemaVersion: Int
    /// When the rates were last checked, as an ISO date (yyyy-MM-dd). Newer files win.
    let asOf: String
    let cards: [CatalogCard]

    static let supportedSchemaVersion = 1

    func card(id: String) -> CatalogCard? {
        cards.first { $0.id == id }
    }
}

/// One card product and how it earns rewards.
nonisolated struct CatalogCard: Codable, Identifiable, Hashable, Sendable {
    let id: String
    let name: String
    let issuer: String
    let network: String
    let annualFee: Int
    let currency: RewardCurrency
    /// Earned on everything that has no higher rate.
    let baseRate: Double
    let categoryRates: [SpendCategory: Double]
    /// Rates at specific merchants, keyed by merchant id from `merchants.json` (e.g. "amazon").
    let merchantRates: [String: Double]?
    /// Set for cards with bonus categories that rotate or that the cardholder picks
    /// (Freedom Flex, Discover it, Custom Cash). The user chooses the current categories.
    let bonusRate: Double?
    let bonusLabel: String?
    /// Card color as a hex string, used for the card art.
    let color: String
    let notes: String?
}

import Foundation
import SwiftData

/// A card the user owns. Only the card product and its reward rates are stored,
/// never a card number.
@Model
final class UserCard {
    var id: UUID
    /// The catalog card this was added from, or nil for a custom card.
    var catalogID: String?
    /// While true, the rates are refreshed whenever a newer catalog arrives.
    /// Editing any rate turns this off so the user's changes stick.
    var followsCatalog: Bool
    /// The catalog `asOf` date these rates came from.
    var syncedAsOf: String?
    var name: String
    var nickname: String?
    var issuer: String
    var currencyRaw: String
    var baseRate: Double
    var categoryRatesData: Data
    var merchantRatesData: Data
    /// 0 when the card has no rotating or choice bonus.
    var bonusRate: Double
    var bonusLabel: String?
    /// The bonus categories the user picked for now. Kept when the catalog refreshes.
    var bonusCategoriesRaw: [String]
    var colorHex: String
    var notes: String
    var sortOrder: Int
    var createdAt: Date

    init(catalogCard card: CatalogCard, asOf: String, sortOrder: Int) {
        id = UUID()
        catalogID = card.id
        followsCatalog = true
        syncedAsOf = asOf
        name = card.name
        issuer = card.issuer
        currencyRaw = card.currency.rawValue
        baseRate = card.baseRate
        categoryRatesData = Self.encode(card.categoryRates)
        merchantRatesData = Self.encode(card.merchantRates ?? [:])
        bonusRate = card.bonusRate ?? 0
        bonusLabel = card.bonusLabel
        bonusCategoriesRaw = []
        colorHex = card.color
        notes = card.notes ?? ""
        self.sortOrder = sortOrder
        createdAt = .now
    }

    init(customNamed name: String, sortOrder: Int) {
        id = UUID()
        catalogID = nil
        followsCatalog = false
        syncedAsOf = nil
        self.name = name
        issuer = ""
        currencyRaw = RewardCurrency.cashBack.rawValue
        baseRate = 1
        categoryRatesData = Self.encode([SpendCategory: Double]())
        merchantRatesData = Self.encode([String: Double]())
        bonusRate = 0
        bonusLabel = nil
        bonusCategoriesRaw = []
        colorHex = "#5B6B7F"
        notes = ""
        self.sortOrder = sortOrder
        createdAt = .now
    }

    var displayName: String {
        if let nickname, !nickname.isEmpty { return nickname }
        return name
    }

    var currency: RewardCurrency {
        get { RewardCurrency(rawValue: currencyRaw) ?? .cashBack }
        set { currencyRaw = newValue.rawValue }
    }

    var categoryRates: [SpendCategory: Double] {
        get { Self.decode(categoryRatesData) ?? [:] }
        set { categoryRatesData = Self.encode(newValue) }
    }

    var merchantRates: [String: Double] {
        get { Self.decode(merchantRatesData) ?? [:] }
        set { merchantRatesData = Self.encode(newValue) }
    }

    var bonusCategories: Set<SpendCategory> {
        get { Set(bonusCategoriesRaw.compactMap(SpendCategory.init(rawValue:))) }
        set { bonusCategoriesRaw = SpendCategory.allCases.filter(newValue.contains).map(\.rawValue) }
    }

    /// Copies the latest terms from the catalog, keeping the nickname and chosen bonus categories.
    func apply(_ card: CatalogCard, asOf: String) {
        name = card.name
        issuer = card.issuer
        currency = card.currency
        baseRate = card.baseRate
        categoryRates = card.categoryRates
        merchantRates = card.merchantRates ?? [:]
        bonusRate = card.bonusRate ?? 0
        bonusLabel = card.bonusLabel
        colorHex = card.color
        notes = card.notes ?? ""
        followsCatalog = true
        syncedAsOf = asOf
    }

    /// The plain value the recommendation engine works with.
    var rewards: CardRewards {
        CardRewards(
            id: id.uuidString,
            name: displayName,
            issuer: issuer,
            currency: currency,
            baseRate: baseRate,
            categoryRates: categoryRates,
            merchantRates: merchantRates,
            bonusCategories: bonusRate > 0 ? bonusCategories : [],
            bonusRate: bonusRate,
            colorHex: colorHex
        )
    }

    private static func encode<T: Encodable>(_ value: T) -> Data {
        (try? JSONEncoder().encode(value)) ?? Data()
    }

    private static func decode<T: Decodable>(_ data: Data) -> T? {
        try? JSONDecoder().decode(T.self, from: data)
    }
}

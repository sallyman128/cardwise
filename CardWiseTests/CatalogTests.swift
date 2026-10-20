import Foundation
import MapKit
import Testing
@testable import CardWise

struct CatalogTests {
    let bundle = Bundle(for: CatalogStore.self)

    @Test func bundledCatalogDecodes() {
        let catalog = CatalogStore.loadBundledCatalog(from: bundle)
        #expect(catalog.cards.count >= 25)
        #expect(Set(catalog.cards.map(\.id)).count == catalog.cards.count, "card ids must be unique")
    }

    @Test func merchantRatesReferToKnownMerchants() {
        let catalog = CatalogStore.loadBundledCatalog(from: bundle)
        let directory = MerchantDirectory(merchants: CatalogStore.loadMerchants(from: bundle))
        for card in catalog.cards {
            for merchantID in (card.merchantRates ?? [:]).keys {
                #expect(directory.merchant(id: merchantID) != nil, "\(card.id) refers to unknown merchant \(merchantID)")
            }
        }
    }

    @Test func merchantIDsAreUnique() {
        let merchants = CatalogStore.loadMerchants(from: bundle)
        #expect(merchants.count >= 100)
        #expect(Set(merchants.map(\.id)).count == merchants.count)
    }

    @Test func rejectsNewerSchemaAndUnknownCategories() {
        let future = #"{"schemaVersion": 99, "asOf": "2030-01-01", "cards": []}"#
        #expect(throws: (any Error).self) { try CatalogStore.decodeCatalog(Data(future.utf8)) }

        let badCategory = #"""
        {"schemaVersion": 1, "asOf": "2030-01-01", "cards": [{"id": "x", "name": "X", "issuer": "X", "network": "Visa",
        "annualFee": 0, "currency": "cashBack", "baseRate": 1, "categoryRates": {"pets": 5}, "color": "#000000"}]}
        """#
        #expect(throws: (any Error).self) { try CatalogStore.decodeCatalog(Data(badCategory.utf8)) }
    }

    @Test func newerCatalogWins() {
        let old = CardCatalog(schemaVersion: 1, asOf: "2026-01-05", cards: [])
        let new = CardCatalog(schemaVersion: 1, asOf: "2026-10-19", cards: [])
        #expect(CatalogStore.isNewer(new, than: old))
        #expect(!CatalogStore.isNewer(old, than: new))
        #expect(!CatalogStore.isNewer(new, than: new))
    }

    @Test func cachedNewerCatalogIsUsed() throws {
        let cacheDirectory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
        let cached = #"""
        {"schemaVersion": 1, "asOf": "2099-01-01", "cards": [{"id": "amex-gold", "name": "Gold Card", "issuer": "American Express",
        "network": "Amex", "annualFee": 325, "currency": "amexMR", "baseRate": 1, "categoryRates": {"dining": 5}, "color": "#000000"}]}
        """#
        try Data(cached.utf8).write(to: cacheDirectory.appending(path: "cards.json"))

        let store = CatalogStore(bundle: bundle, cacheDirectory: cacheDirectory)
        #expect(store.source == .downloaded)
        #expect(store.catalog.card(id: "amex-gold")?.categoryRates[.dining] == 5)
    }

    @Test func syncUpdatesFollowingCardsOnly() throws {
        let original = try #require(CatalogStore.loadBundledCatalog(from: bundle).card(id: "amex-gold"))
        let following = UserCard(catalogCard: original, asOf: "2000-01-01", sortOrder: 0)
        let customized = UserCard(catalogCard: original, asOf: "2000-01-01", sortOrder: 1)
        customized.followsCatalog = false
        customized.baseRate = 9

        let store = CatalogStore(bundle: bundle, cacheDirectory: nil)
        following.baseRate = 7
        store.sync([following, customized])

        #expect(following.baseRate == original.baseRate)
        #expect(following.syncedAsOf == store.catalog.asOf)
        #expect(customized.baseRate == 9)
    }

    // MARK: Merchant matching

    @Test func matchesPlaceNamesToMerchants() {
        let directory = MerchantDirectory(merchants: CatalogStore.loadMerchants(from: bundle))
        #expect(directory.match(placeName: "Costco Wholesale")?.id == "costco")
        #expect(directory.match(placeName: "Whole Foods Market")?.id == "wholefoods")
        #expect(directory.match(placeName: "The Home Depot")?.id == "homedepot")
        #expect(directory.match(placeName: "Trader Joe’s")?.id == "traderjoes")
        #expect(directory.match(placeName: "Hampton Inn & Suites Boston")?.id == "hilton")
        #expect(directory.match(placeName: "Big Apple Pizza") == nil)
        #expect(directory.match(placeName: "United States Post Office") == nil)
        #expect(directory.match(placeName: "Applebee's Grill + Bar")?.id == "applebees")
    }

    @Test func searchRanksPrefixMatchesFirst() {
        let directory = MerchantDirectory(merchants: CatalogStore.loadMerchants(from: bundle))
        #expect(directory.search("door").first?.id == "doordash")
        #expect(directory.search("uber").prefix(2).map(\.id).sorted() == ["uber", "ubereats"])
        #expect(directory.search("depot").first?.id == "homedepot")
        #expect(directory.search("").isEmpty)
    }

    // MARK: Category mapping

    @Test func merchantOverridesMapsCategory() {
        let directory = MerchantDirectory(merchants: CatalogStore.loadMerchants(from: bundle))
        #expect(CategoryMapper.category(for: .foodMarket, merchant: directory.merchant(id: "costco")) == .wholesaleClubs)
        #expect(CategoryMapper.category(for: .foodMarket, merchant: nil) == .groceries)
        #expect(CategoryMapper.category(for: .cafe, merchant: nil) == .dining)
        #expect(CategoryMapper.category(for: .fitnessCenter, merchant: nil) == .other)
        #expect(CategoryMapper.category(for: nil, merchant: nil) == .other)
    }
}

struct ValuationTests {
    let bundle = Bundle(for: CatalogStore.self)

    @Test func bundledValuationsCoverEveryCurrency() throws {
        let store = ValuationStore(bundle: bundle, cacheDirectory: nil)
        for currency in RewardCurrency.allCases {
            let entry = try #require(store.published.currencies[currency], "missing \(currency)")
            #expect(entry.cash > 0 && entry.travel > 0)
            #expect(entry.cash <= entry.travel, "\(currency): cash value above travel value")
        }
        #expect(!store.published.sources.isEmpty)
    }

    @Test func userEditsBeatPublishedValues() {
        var valuations = Valuations()
        #expect(valuations.valuation(for: .chaseUR) == RewardCurrency.chaseUR.defaultValuation)

        valuations.published[.chaseUR] = Valuation(cash: 1.0, travel: 2.05)
        #expect(valuations.valuation(for: .chaseUR).travel == 2.05)

        valuations.overrides[.chaseUR] = Valuation(cash: 1.0, travel: 1.5)
        #expect(valuations.valuation(for: .chaseUR).travel == 1.5)
        #expect(valuations.baseline(for: .chaseUR).travel == 2.05)
    }

    @Test func publishedValuesAreNotSaved() throws {
        var valuations = Valuations()
        valuations.published[.amexMR] = Valuation(cash: 0.6, travel: 2.0)
        valuations.overrides[.chaseUR] = Valuation(cash: 1.0, travel: 1.5)
        let decoded = try JSONDecoder().decode(Valuations.self, from: JSONEncoder().encode(valuations))
        #expect(decoded.published.isEmpty)
        #expect(decoded.overrides[.chaseUR]?.travel == 1.5)
    }
}

import Testing
@testable import CardWise

struct RecommendationEngineTests {
    let amexGold = card("Gold", .amexMR, base: 1, rates: [.dining: 4, .groceries: 4, .airfare: 3])
    let sapphirePreferred = card("Sapphire Preferred", .chaseUR, base: 1, rates: [.dining: 3, .travel: 2])
    let doubleCash = card("Double Cash", .cashBack, base: 2)
    let primeVisa = card("Prime Visa", .cashBack, base: 1, rates: [.dining: 2], merchants: ["amazon": 5])
    let freedomFlex = card("Freedom Flex", .chaseUR, base: 1, rates: [.dining: 3], bonus: [.gas], bonusRate: 5)

    let amazon = Merchant(id: "amazon", name: "Amazon", aliases: nil, category: .onlineShopping, online: true, note: nil)
    let costco = Merchant(id: "costco", name: "Costco", aliases: nil, category: .wholesaleClubs, online: false, note: nil)

    // MARK: Earn rates

    @Test func fallsBackToBaseRate() {
        let earned = RecommendationEngine.earnRate(for: doubleCash, on: PurchaseContext(category: .dining))
        #expect(earned.rate == 2)
        #expect(earned.reason == .base)
    }

    @Test func usesCategoryRate() {
        let earned = RecommendationEngine.earnRate(for: amexGold, on: PurchaseContext(category: .groceries))
        #expect(earned.rate == 4)
        #expect(earned.reason == .category(.groceries))
    }

    @Test func subcategoryInheritsParentRate() {
        let earned = RecommendationEngine.earnRate(for: sapphirePreferred, on: PurchaseContext(category: .hotels))
        #expect(earned.rate == 2)
        #expect(earned.reason == .category(.travel))
    }

    @Test func specificRateBeatsParentRate() {
        let earned = RecommendationEngine.earnRate(for: amexGold, on: PurchaseContext(category: .airfare))
        #expect(earned.rate == 3)
        #expect(earned.reason == .category(.airfare))
    }

    @Test func merchantRateBeatsCategory() {
        let earned = RecommendationEngine.earnRate(for: primeVisa, on: PurchaseContext(merchant: amazon))
        #expect(earned.rate == 5)
        #expect(earned.reason == .merchant("Amazon"))
    }

    @Test func bonusCategoryApplies() {
        let earned = RecommendationEngine.earnRate(for: freedomFlex, on: PurchaseContext(category: .gas))
        #expect(earned.rate == 5)
        #expect(earned.reason == .bonus(.gas))
    }

    @Test func wholesaleClubIsNotGroceries() {
        let earned = RecommendationEngine.earnRate(for: amexGold, on: PurchaseContext(merchant: costco))
        #expect(earned.rate == 1)
        #expect(earned.reason == .base)
    }

    // MARK: Ranking

    @Test func cashGoalRanksByCashValue() {
        // Cash: Gold 4 × 1.0 = 4, Sapphire 3 × 1.5 = 4.5, Double Cash 2.
        let ranked = rank([amexGold, sapphirePreferred, doubleCash], .dining, goal: .maxCash)
        #expect(ranked.map(\.card.name) == ["Sapphire Preferred", "Gold", "Double Cash"])
        #expect(ranked[0].centsPerDollar == 4.5)
    }

    @Test func travelGoalUsesTravelValues() {
        // Travel: Gold 4 × 2.0 = 8, Sapphire 3 × 2.0 = 6, Double Cash 2.
        let ranked = rank([doubleCash, sapphirePreferred, amexGold], .dining, goal: .maxTravel)
        #expect(ranked.map(\.card.name) == ["Gold", "Sapphire Preferred", "Double Cash"])
        #expect(ranked[0].centsPerDollar == 8)
    }

    @Test func programGoalPutsThatProgramFirst() {
        let ranked = rank([amexGold, doubleCash, sapphirePreferred, freedomFlex], .dining, goal: .program(.chaseUR))
        #expect(ranked.map(\.card.name) == ["Freedom Flex", "Sapphire Preferred", "Gold", "Double Cash"])
        #expect(ranked[0].earnsGoalProgram)
        #expect(!ranked[2].earnsGoalProgram)
    }

    @Test func customValuationsChangeTheOrder() {
        var valuations = Valuations()
        valuations.overrides[.amexMR] = Valuation(cash: 0.6, travel: 1.0)
        let ranked = RecommendationEngine.rank(
            [amexGold, doubleCash], for: PurchaseContext(category: .other), goal: .maxCash, valuations: valuations)
        #expect(ranked.first?.card.name == "Double Cash")
    }

    @Test func tiesSortByName() {
        let a = card("B Card", .cashBack, base: 2)
        let b = card("A Card", .cashBack, base: 2)
        let ranked = rank([a, b], .other, goal: .maxCash)
        #expect(ranked.map(\.card.name) == ["A Card", "B Card"])
    }

    @Test func descriptions() {
        let ranked = rank([amexGold, doubleCash], .dining, goal: .maxTravel)
        #expect(ranked[0].rateDescription == "4x MR on Dining")
        #expect(ranked[0].valueDescription == "≈ 8¢ per $1")
        #expect(ranked[1].rateDescription == "2% on everything")
        #expect(ranked[1].valueDescription == nil)
    }

    // MARK: Helpers

    private func rank(_ cards: [CardRewards], _ category: SpendCategory, goal: RewardGoal) -> [Recommendation] {
        RecommendationEngine.rank(cards, for: PurchaseContext(category: category), goal: goal, valuations: Valuations())
    }
}

func card(
    _ name: String,
    _ currency: RewardCurrency,
    base: Double,
    rates: [SpendCategory: Double] = [:],
    merchants: [String: Double] = [:],
    bonus: Set<SpendCategory> = [],
    bonusRate: Double = 0
) -> CardRewards {
    CardRewards(
        id: name, name: name, issuer: "", currency: currency, baseRate: base,
        categoryRates: rates, merchantRates: merchants,
        bonusCategories: bonus, bonusRate: bonusRate, colorHex: "#000000")
}

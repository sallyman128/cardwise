import Foundation

/// A card's earning rules, as plain values the engine can rank.
nonisolated struct CardRewards: Identifiable, Hashable, Sendable {
    let id: String
    let name: String
    let issuer: String
    let currency: RewardCurrency
    let baseRate: Double
    let categoryRates: [SpendCategory: Double]
    let merchantRates: [String: Double]
    let bonusCategories: Set<SpendCategory>
    let bonusRate: Double
    let colorHex: String
}

/// What's being bought: always a category, sometimes a known merchant too.
nonisolated struct PurchaseContext: Hashable, Sendable {
    let category: SpendCategory
    let merchant: Merchant?

    init(category: SpendCategory, merchant: Merchant? = nil) {
        self.category = category
        self.merchant = merchant
    }

    init(merchant: Merchant) {
        self.init(category: merchant.category, merchant: merchant)
    }

    var title: String { merchant?.name ?? category.displayName }
}

/// Why a card earns what it does on a purchase.
nonisolated enum EarnReason: Hashable, Sendable {
    case merchant(String)
    case bonus(SpendCategory)
    case category(SpendCategory)
    case base
}

nonisolated struct Recommendation: Identifiable, Hashable, Sendable {
    let card: CardRewards
    let rate: Double
    let reason: EarnReason
    /// Estimated value in cents per $1 spent, using the user's point values for the goal.
    let centsPerDollar: Double
    /// For a program goal: whether this card earns that program's points.
    let earnsGoalProgram: Bool

    var id: String { card.id }

    /// e.g. "4x MR on Dining" or "5% at Amazon".
    var rateDescription: String {
        let rateText = RecommendationEngine.format(rate)
        let earned = card.currency.isCashBack ? "\(rateText)%" : "\(rateText)x \(card.currency.shortName)"
        switch reason {
        case .merchant(let name): return "\(earned) at \(name)"
        case .bonus(let category): return "\(earned) on \(category.displayName) (bonus)"
        case .category(let category): return "\(earned) on \(category.displayName)"
        case .base: return "\(earned) on everything"
        }
    }

    /// e.g. "≈ 8¢ per $1". Nil for cash back, where the rate already says it.
    var valueDescription: String? {
        guard !card.currency.isCashBack else { return nil }
        return "≈ \(RecommendationEngine.format(centsPerDollar))¢ per $1"
    }
}

/// Ranks cards for a purchase. Pure logic with no UI or storage, so it's easy to test.
nonisolated enum RecommendationEngine {
    /// The best rate a card earns on a purchase. Issuers pay the highest rate that applies,
    /// so this takes the max of the merchant, bonus, category and base rates.
    /// On a tie, the more specific reason is reported.
    static func earnRate(for card: CardRewards, on purchase: PurchaseContext) -> (rate: Double, reason: EarnReason) {
        var best: (rate: Double, reason: EarnReason) = (card.baseRate, .base)

        // Checked from least to most specific; `>=` lets a more specific reason win a tie.
        func consider(_ rate: Double?, _ reason: EarnReason) {
            guard let rate, rate >= best.rate else { return }
            best = (rate, reason)
        }

        let categories = [purchase.category, purchase.category.parent].compactMap { $0 }
        for category in categories.reversed() {
            consider(card.categoryRates[category], .category(category))
        }
        for category in categories.reversed() where card.bonusCategories.contains(category) {
            consider(card.bonusRate, .bonus(category))
        }
        if let merchant = purchase.merchant {
            consider(card.merchantRates[merchant.id], .merchant(merchant.name))
        }
        return best
    }

    static func rank(
        _ cards: [CardRewards],
        for purchase: PurchaseContext,
        goal: RewardGoal,
        valuations: Valuations
    ) -> [Recommendation] {
        let recommendations = cards.map { card in
            let (rate, reason) = earnRate(for: card, on: purchase)
            let cents = rate * valuations.cents(for: card.currency, goal: goal)
            let earnsGoal: Bool
            if case .program(let currency) = goal { earnsGoal = card.currency == currency } else { earnsGoal = false }
            return Recommendation(card: card, rate: rate, reason: reason, centsPerDollar: cents, earnsGoalProgram: earnsGoal)
        }

        return recommendations.sorted { a, b in
            if case .program = goal {
                if a.earnsGoalProgram != b.earnsGoalProgram { return a.earnsGoalProgram }
                if a.earnsGoalProgram, a.rate != b.rate { return a.rate > b.rate }
            }
            if a.centsPerDollar != b.centsPerDollar { return a.centsPerDollar > b.centsPerDollar }
            return a.card.name.localizedStandardCompare(b.card.name) == .orderedAscending
        }
    }

    /// "4", "1.5", "1.85"
    static func format(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(0...2)))
    }
}

import Foundation

/// What a card earns. Cash back is counted in percent, everything else in points or miles.
nonisolated enum RewardCurrency: String, Codable, CodingKeyRepresentable, CaseIterable, Identifiable, Sendable {
    case cashBack
    case chaseUR
    case amexMR
    case capitalOneMiles
    case citiThankYou
    case biltPoints
    case wellsFargoRewards
    case deltaSkyMiles
    case unitedMiles
    case marriottBonvoy
    case hiltonHonors

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .cashBack: "Cash back"
        case .chaseUR: "Chase Ultimate Rewards"
        case .amexMR: "Amex Membership Rewards"
        case .capitalOneMiles: "Capital One Miles"
        case .citiThankYou: "Citi ThankYou Points"
        case .biltPoints: "Bilt Points"
        case .wellsFargoRewards: "Wells Fargo Rewards"
        case .deltaSkyMiles: "Delta SkyMiles"
        case .unitedMiles: "United MileagePlus"
        case .marriottBonvoy: "Marriott Bonvoy"
        case .hiltonHonors: "Hilton Honors"
        }
    }

    /// Short label used next to a multiplier, e.g. "4x MR".
    var shortName: String {
        switch self {
        case .cashBack: "cash back"
        case .chaseUR: "UR"
        case .amexMR: "MR"
        case .capitalOneMiles: "miles"
        case .citiThankYou: "TYP"
        case .biltPoints: "Bilt"
        case .wellsFargoRewards: "WF pts"
        case .deltaSkyMiles: "SkyMiles"
        case .unitedMiles: "United miles"
        case .marriottBonvoy: "Bonvoy"
        case .hiltonHonors: "Hilton pts"
        }
    }

    var isCashBack: Bool { self == .cashBack }

    /// Starting values in cents per point. Users can change these in Settings.
    var defaultValuation: Valuation {
        switch self {
        case .cashBack: Valuation(cash: 1.0, travel: 1.0)
        case .chaseUR: Valuation(cash: 1.5, travel: 2.0)
        case .amexMR: Valuation(cash: 1.0, travel: 2.0)
        case .capitalOneMiles: Valuation(cash: 1.0, travel: 1.85)
        case .citiThankYou: Valuation(cash: 1.0, travel: 1.8)
        case .biltPoints: Valuation(cash: 1.0, travel: 2.0)
        case .wellsFargoRewards: Valuation(cash: 1.0, travel: 1.5)
        case .deltaSkyMiles: Valuation(cash: 1.0, travel: 1.2)
        case .unitedMiles: Valuation(cash: 1.0, travel: 1.35)
        case .marriottBonvoy: Valuation(cash: 0.6, travel: 0.8)
        case .hiltonHonors: Valuation(cash: 0.4, travel: 0.5)
        }
    }
}

/// How much one point is worth, in cents, when redeemed for cash vs. travel.
nonisolated struct Valuation: Codable, Hashable, Sendable {
    var cash: Double
    var travel: Double
}

/// The user's point values: defaults plus anything they changed.
nonisolated struct Valuations: Codable, Hashable, Sendable {
    var overrides: [RewardCurrency: Valuation] = [:]

    func valuation(for currency: RewardCurrency) -> Valuation {
        overrides[currency] ?? currency.defaultValuation
    }

    /// Cents one point is worth under the given goal.
    func cents(for currency: RewardCurrency, goal: RewardGoal) -> Double {
        let value = valuation(for: currency)
        switch goal {
        case .maxCash: return value.cash
        case .maxTravel, .program: return value.travel
        }
    }
}

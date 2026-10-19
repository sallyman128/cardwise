import Foundation

/// What the user is optimizing for.
nonisolated enum RewardGoal: Hashable, Codable, Sendable {
    /// Most cents back per dollar, valuing points at what they're worth as cash.
    case maxCash
    /// Most cents back per dollar, valuing points at what they're worth for travel.
    case maxTravel
    /// Earn as much of one program as possible.
    case program(RewardCurrency)

    var title: String {
        switch self {
        case .maxCash: "Most cash value"
        case .maxTravel: "Most travel value"
        case .program(let currency): "Most \(currency.displayName)"
        }
    }
}

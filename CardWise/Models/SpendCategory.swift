import Foundation

/// The kinds of purchases card issuers reward differently. Every recommendation is
/// resolved through one of these, whether the purchase came from a nearby place or a search.
nonisolated enum SpendCategory: String, Codable, CodingKeyRepresentable, CaseIterable, Identifiable, Sendable {
    case dining
    case groceries
    case gas
    case travel
    case airfare
    case hotels
    case rideshare
    case transit
    case streaming
    case drugstores
    case onlineShopping
    case homeImprovement
    case entertainment
    case wholesaleClubs
    case other

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .dining: "Dining"
        case .groceries: "Groceries"
        case .gas: "Gas & EV charging"
        case .travel: "Travel"
        case .airfare: "Flights"
        case .hotels: "Hotels"
        case .rideshare: "Rideshare"
        case .transit: "Transit & parking"
        case .streaming: "Streaming"
        case .drugstores: "Drugstores"
        case .onlineShopping: "Online shopping"
        case .homeImprovement: "Home improvement"
        case .entertainment: "Entertainment"
        case .wholesaleClubs: "Wholesale clubs"
        case .other: "Everything else"
        }
    }

    var symbol: String {
        switch self {
        case .dining: "fork.knife"
        case .groceries: "cart"
        case .gas: "fuelpump"
        case .travel: "suitcase"
        case .airfare: "airplane"
        case .hotels: "bed.double"
        case .rideshare: "car"
        case .transit: "tram"
        case .streaming: "play.tv"
        case .drugstores: "cross.case"
        case .onlineShopping: "bag"
        case .homeImprovement: "hammer"
        case .entertainment: "ticket"
        case .wholesaleClubs: "shippingbox"
        case .other: "creditcard"
        }
    }

    /// The broader category a card's rate falls back to: a card earning 3x on travel
    /// also earns 3x on flights, hotels, rideshare and transit.
    var parent: SpendCategory? {
        switch self {
        case .airfare, .hotels, .rideshare, .transit: .travel
        default: nil
        }
    }
}

import MapKit

/// Turns what Apple Maps knows about a place into the category a card would reward.
enum CategoryMapper {
    /// A known merchant beats the Maps category. Maps calls Costco a store or market,
    /// but card issuers code it as a wholesale club.
    static func category(for poiCategory: MKPointOfInterestCategory?, merchant: Merchant?) -> SpendCategory {
        if let merchant { return merchant.category }
        guard let poiCategory else { return .other }
        return mapping[poiCategory] ?? .other
    }

    static let mapping: [MKPointOfInterestCategory: SpendCategory] = [
        .restaurant: .dining,
        .cafe: .dining,
        .bakery: .dining,
        .brewery: .dining,
        .winery: .dining,
        .distillery: .dining,
        .nightlife: .dining,
        .foodMarket: .groceries,
        .gasStation: .gas,
        .evCharger: .gas,
        .pharmacy: .drugstores,
        .hotel: .hotels,
        .airport: .travel,
        .carRental: .travel,
        .campground: .travel,
        .rvPark: .travel,
        .publicTransport: .transit,
        .parking: .transit,
        .movieTheater: .entertainment,
        .theater: .entertainment,
        .musicVenue: .entertainment,
        .stadium: .entertainment,
        .amusementPark: .entertainment,
        .aquarium: .entertainment,
        .zoo: .entertainment,
        .museum: .entertainment,
        .bowling: .entertainment,
        .miniGolf: .entertainment,
        .goKart: .entertainment,
        .planetarium: .entertainment,
    ]

    /// Places where a card purchase is unlikely, left out of nearby results.
    static let excluded: [MKPointOfInterestCategory] = [
        .atm, .bank, .hospital, .police, .fireStation, .school, .university, .library,
        .postOffice, .restroom, .park, .nationalPark, .beach, .landmark, .mailbox,
    ]
}

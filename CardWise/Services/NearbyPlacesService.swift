import CoreLocation
import MapKit

/// A place near the user that a card could be used at.
struct NearbyPlace: Identifiable, Hashable {
    let id: String
    let name: String
    let coordinate: CLLocationCoordinate2D
    let distance: CLLocationDistance
    let category: SpendCategory
    let merchant: Merchant?

    var purchase: PurchaseContext { PurchaseContext(category: category, merchant: merchant) }

    static func == (lhs: NearbyPlace, rhs: NearbyPlace) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

/// Finds businesses around a location using Apple Maps points of interest.
enum NearbyPlacesService {
    /// Searches close by first, then a bit wider if nothing is right there.
    static func places(near location: CLLocation, directory: MerchantDirectory) async throws -> [NearbyPlace] {
        for radius in [75.0, 250.0] {
            let places = try await search(near: location, radius: radius, directory: directory)
            if !places.isEmpty { return places }
        }
        return []
    }

    private static func search(near location: CLLocation, radius: CLLocationDistance, directory: MerchantDirectory) async throws -> [NearbyPlace] {
        let request = MKLocalPointsOfInterestRequest(center: location.coordinate, radius: radius)
        request.pointOfInterestFilter = MKPointOfInterestFilter(excluding: CategoryMapper.excluded)

        let response: MKLocalSearch.Response
        do {
            response = try await MKLocalSearch(request: request).start()
        } catch let error as MKError where error.code == .placemarkNotFound {
            return []
        }

        var seen = Set<String>()
        return response.mapItems
            .compactMap { item -> NearbyPlace? in
                guard let name = item.name else { return nil }
                let coordinate = item.placemark.coordinate
                let id = "\(name)|\(String(format: "%.5f,%.5f", coordinate.latitude, coordinate.longitude))"
                guard seen.insert(id).inserted else { return nil }
                let merchant = directory.match(placeName: name)
                return NearbyPlace(
                    id: id,
                    name: name,
                    coordinate: coordinate,
                    distance: location.distance(from: CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)),
                    category: CategoryMapper.category(for: item.pointOfInterestCategory, merchant: merchant),
                    merchant: merchant
                )
            }
            .sorted { $0.distance < $1.distance }
    }
}

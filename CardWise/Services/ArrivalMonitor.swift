import CoreLocation
import Observation
import SwiftData
import UIKit
import UserNotifications

/// Notifies the user which card to use when they arrive somewhere.
///
/// Uses iOS visit monitoring, which is low power and relaunches the app in the background
/// when the user has arrived and stayed put. It needs "Always" location access.
@Observable
final class ArrivalMonitor: NSObject, CLLocationManagerDelegate, UNUserNotificationCenterDelegate {
    struct MutedPlace: Codable, Hashable {
        let latitude: Double
        let longitude: Double
    }

    private(set) var authorization: CLAuthorizationStatus
    private(set) var notificationsDenied = false
    private(set) var isEnabled: Bool
    private(set) var mutedPlaces: [MutedPlace]

    @ObservationIgnored private let manager = CLLocationManager()
    @ObservationIgnored private let container: ModelContainer
    @ObservationIgnored private let directory: MerchantDirectory
    @ObservationIgnored private let settings: AppSettings
    @ObservationIgnored private let defaults = UserDefaults.standard

    private enum Keys {
        static let enabled = "arrivalAlertsEnabled"
        static let muted = "arrivalMutedPlaces"
        static let lastPlace = "arrivalLastPlaceID"
        static let lastDate = "arrivalLastDate"
    }

    static let category = "ARRIVAL"
    nonisolated static let muteAction = "MUTE_PLACE"
    /// Don't repeat an alert for the same place within this many seconds.
    static let repeatInterval: TimeInterval = 3 * 60 * 60
    /// Arrivals within this many meters of a muted place are ignored.
    static let muteRadius: CLLocationDistance = 100

    init(container: ModelContainer, directory: MerchantDirectory, settings: AppSettings) {
        self.container = container
        self.directory = directory
        self.settings = settings
        authorization = manager.authorizationStatus
        isEnabled = defaults.bool(forKey: Keys.enabled)
        mutedPlaces = (defaults.data(forKey: Keys.muted)).flatMap { try? JSONDecoder().decode([MutedPlace].self, from: $0) } ?? []
        super.init()
        manager.delegate = self
    }

    var hasAlwaysAccess: Bool { authorization == .authorizedAlways }

    /// Call at launch, including background relaunches, so visits keep being delivered.
    func start() {
        let center = UNUserNotificationCenter.current()
        center.delegate = self
        center.setNotificationCategories([
            UNNotificationCategory(
                identifier: Self.category,
                actions: [UNNotificationAction(identifier: Self.muteAction, title: "Don't Notify Me Here")],
                intentIdentifiers: []
            )
        ])
        if isEnabled, hasAlwaysAccess {
            manager.startMonitoringVisits()
        }
        Task { await refreshNotificationStatus() }
    }

    func enable() async {
        isEnabled = true
        defaults.set(true, forKey: Keys.enabled)
        let granted = (try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])) ?? false
        notificationsDenied = !granted
        // From "not determined" this shows the usual prompt; from "While Using" it offers the upgrade to Always.
        manager.requestAlwaysAuthorization()
        if hasAlwaysAccess { manager.startMonitoringVisits() }
    }

    func disable() {
        isEnabled = false
        defaults.set(false, forKey: Keys.enabled)
        manager.stopMonitoringVisits()
    }

    func clearMutedPlaces() {
        mutedPlaces = []
        defaults.removeObject(forKey: Keys.muted)
    }

    func refreshNotificationStatus() async {
        let status = await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
        notificationsDenied = status == .denied
    }

    // MARK: - Arrivals

    /// Finds the place at `location`, picks the best card and posts a notification.
    /// `force` skips the repeat check, for the test button in Settings.
    func handleArrival(at location: CLLocation, force: Bool = false) async {
        guard !isMuted(location) else { return }

        let backgroundTask = UIApplication.shared.beginBackgroundTask(withName: "CardWise arrival")
        defer { UIApplication.shared.endBackgroundTask(backgroundTask) }

        guard let places = try? await NearbyPlacesService.places(near: location, directory: directory),
              let place = places.first,
              place.distance <= max(60, min(location.horizontalAccuracy, 120)) else { return }

        if !force,
           defaults.string(forKey: Keys.lastPlace) == place.id,
           let last = defaults.object(forKey: Keys.lastDate) as? Date,
           Date.now.timeIntervalSince(last) < Self.repeatInterval {
            return
        }

        let descriptor = FetchDescriptor<UserCard>(sortBy: [SortDescriptor(\.sortOrder)])
        let cards = ((try? container.mainContext.fetch(descriptor)) ?? []).map(\.rewards)
        let ranked = RecommendationEngine.rank(cards, for: place.purchase, goal: settings.goal, valuations: settings.valuations)
        guard let best = ranked.first else { return }

        let content = UNMutableNotificationContent()
        content.title = place.name
        content.body = "Use \(best.card.name) · \(best.rateDescription)"
        if let value = best.valueDescription { content.body += " (\(value))" }
        content.threadIdentifier = "arrival"
        content.categoryIdentifier = Self.category
        content.userInfo = ["latitude": place.coordinate.latitude, "longitude": place.coordinate.longitude]

        let request = UNNotificationRequest(identifier: "arrival-\(place.id)", content: content, trigger: nil)
        try? await UNUserNotificationCenter.current().add(request)
        defaults.set(place.id, forKey: Keys.lastPlace)
        defaults.set(Date.now, forKey: Keys.lastDate)
    }

    private func isMuted(_ location: CLLocation) -> Bool {
        mutedPlaces.contains { muted in
            location.distance(from: CLLocation(latitude: muted.latitude, longitude: muted.longitude)) < Self.muteRadius
        }
    }

    private func mute(latitude: Double, longitude: Double) {
        mutedPlaces.append(MutedPlace(latitude: latitude, longitude: longitude))
        defaults.set(try? JSONEncoder().encode(mutedPlaces), forKey: Keys.muted)
    }

    // MARK: - CLLocationManagerDelegate

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        Task { @MainActor in
            self.authorization = status
            if self.isEnabled, status == .authorizedAlways {
                self.manager.startMonitoringVisits()
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didVisit visit: CLVisit) {
        // A visit with a departure date is the user leaving; only arrivals matter.
        guard visit.departureDate == .distantFuture else { return }
        let location = CLLocation(
            coordinate: visit.coordinate,
            altitude: 0,
            horizontalAccuracy: visit.horizontalAccuracy,
            verticalAccuracy: -1,
            timestamp: visit.arrivalDate
        )
        Task { @MainActor in await self.handleArrival(at: location) }
    }

    // MARK: - UNUserNotificationCenterDelegate

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .list]
    }

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse) async {
        guard response.actionIdentifier == Self.muteAction else { return }
        let info = response.notification.request.content.userInfo
        guard let latitude = info["latitude"] as? Double, let longitude = info["longitude"] as? Double else { return }
        await MainActor.run { self.mute(latitude: latitude, longitude: longitude) }
    }
}

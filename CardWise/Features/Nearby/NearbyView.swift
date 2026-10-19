import MapKit
import SwiftUI

@Observable
final class NearbyModel {
    enum Phase: Equatable {
        case idle
        case needsPermission
        case denied
        case locating
        case loaded
        case empty
        case failed(String)
    }

    private(set) var phase: Phase = .idle
    private(set) var places: [NearbyPlace] = []
    var selectedID: String?
    /// Categories the user corrected by hand, keyed by place id.
    var categoryOverrides: [String: SpendCategory] = [:]

    let location = LocationService()

    var selectedPlace: NearbyPlace? {
        places.first { $0.id == selectedID } ?? places.first
    }

    func purchase(for place: NearbyPlace) -> PurchaseContext {
        PurchaseContext(category: categoryOverrides[place.id] ?? place.category, merchant: place.merchant)
    }

    func load(directory: MerchantDirectory) async {
        if location.isDenied {
            phase = .denied
            return
        }
        guard location.isAuthorized else {
            phase = .needsPermission
            return
        }
        if places.isEmpty { phase = .locating }
        do {
            let here = try await location.currentLocation()
            let found = try await NearbyPlacesService.places(near: here, directory: directory)
            places = found
            if !found.contains(where: { $0.id == selectedID }) { selectedID = found.first?.id }
            phase = found.isEmpty ? .empty : .loaded
        } catch {
            phase = places.isEmpty ? .failed("Couldn't find where you are. Try again in a moment.") : .loaded
        }
    }
}

struct NearbyView: View {
    @State private var model = NearbyModel()
    @State private var mapPosition: MapCameraPosition = .userLocation(fallback: .automatic)
    @Environment(CatalogStore.self) private var catalog
    @Environment(\.openURL) private var openURL

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Nearby")
                .toolbar {
                    if model.phase == .loaded || model.phase == .empty {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button("Refresh", systemImage: "arrow.clockwise") {
                                Task { await reload() }
                            }
                        }
                    }
                }
        }
        .task { await reload() }
        .onChange(of: model.location.authorization) {
            Task { await reload() }
        }
        .onChange(of: model.selectedPlace) { _, place in
            guard let place else { return }
            withAnimation {
                mapPosition = .region(MKCoordinateRegion(center: place.coordinate, latitudinalMeters: 350, longitudinalMeters: 350))
            }
        }
    }

    private func reload() async {
        await model.load(directory: catalog.directory)
    }

    @ViewBuilder
    private var content: some View {
        switch model.phase {
        case .idle, .locating:
            ProgressView("Finding where you are…")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .needsPermission:
            ContentUnavailableView {
                Label("Find the best card here", systemImage: "location.circle")
            } description: {
                Text("CardWise looks up the place you're at to suggest a card. Your location stays on your phone.")
            } actions: {
                Button("Use My Location") { model.location.requestPermission() }
                    .buttonStyle(.borderedProminent)
            }
        case .denied:
            ContentUnavailableView {
                Label("Location is off", systemImage: "location.slash")
            } description: {
                Text("Turn on location for CardWise in Settings, or use the Search tab to look up a store.")
            } actions: {
                Button("Open Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                }
            }
        case .empty:
            ContentUnavailableView {
                Label("No places nearby", systemImage: "mappin.slash")
            } description: {
                Text("Apple Maps didn't find a business here. Try Search instead.")
            } actions: {
                Button("Try Again") { Task { await reload() } }
            }
        case .failed(let message):
            ContentUnavailableView {
                Label("Couldn't get your location", systemImage: "exclamationmark.triangle")
            } description: {
                Text(message)
            } actions: {
                Button("Try Again") { Task { await reload() } }
            }
        case .loaded:
            if let place = model.selectedPlace {
                loaded(place)
            }
        }
    }

    private func loaded(_ place: NearbyPlace) -> some View {
        ScrollView {
            VStack(spacing: 24) {
                Map(position: $mapPosition, interactionModes: []) {
                    UserAnnotation()
                    Marker(place.name, systemImage: model.purchase(for: place).category.symbol, coordinate: place.coordinate)
                }
                .frame(height: 140)
                .clipShape(.rect(cornerRadius: 16))

                PlaceHeader(
                    place: place,
                    category: Binding(
                        get: { model.purchase(for: place).category },
                        set: { model.categoryOverrides[place.id] = $0 }
                    )
                )

                RecommendationList(purchase: model.purchase(for: place))

                otherPlaces(excluding: place)
            }
            .padding()
        }
        .refreshable { await reload() }
    }

    @ViewBuilder
    private func otherPlaces(excluding current: NearbyPlace) -> some View {
        let others = model.places.filter { $0.id != current.id }.prefix(8)
        if !others.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text("Somewhere else?")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)
                VStack(spacing: 0) {
                    ForEach(Array(others.enumerated()), id: \.element.id) { index, place in
                        if index > 0 { Divider().padding(.leading, 52) }
                        Button {
                            withAnimation { model.selectedID = place.id }
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: model.purchase(for: place).category.symbol)
                                    .frame(width: 28)
                                    .foregroundStyle(.tint)
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(place.name).foregroundStyle(.primary)
                                    Text(model.purchase(for: place).category.displayName)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Text(place.distance.formattedDistance)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.horizontal)
                            .padding(.vertical, 10)
                            .contentShape(.rect)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .background(.background.secondary, in: .rect(cornerRadius: 14))
            }
        }
    }
}

private struct PlaceHeader: View {
    let place: NearbyPlace
    @Binding var category: SpendCategory

    var body: some View {
        VStack(spacing: 8) {
            Text("You're at")
                .font(.caption.weight(.semibold))
                .textCase(.uppercase)
                .foregroundStyle(.secondary)
            Text(place.name)
                .font(.title.weight(.bold))
                .multilineTextAlignment(.center)
            HStack(spacing: 8) {
                Menu {
                    Picker("Category", selection: $category) {
                        ForEach(SpendCategory.allCases) { category in
                            Label(category.displayName, systemImage: category.symbol).tag(category)
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Label(category.displayName, systemImage: category.symbol)
                        Image(systemName: "chevron.up.chevron.down").imageScale(.small)
                    }
                    .font(.subheadline.weight(.medium))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(.tint.opacity(0.12), in: .capsule)
                }
                .accessibilityLabel("Category: \(category.displayName). Change category")
                Text(place.distance.formattedDistance)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

private extension CLLocationDistance {
    var formattedDistance: String {
        Measurement(value: self, unit: UnitLength.meters)
            .formatted(.measurement(width: .abbreviated, usage: .road))
    }
}

import SwiftData
import SwiftUI

struct RootView: View {
    static let onboardedKey = "hasOnboarded"

    @AppStorage(RootView.onboardedKey) private var hasOnboarded = false
    @Environment(CatalogStore.self) private var catalog
    @Environment(AppSettings.self) private var settings
    @Environment(ValuationStore.self) private var valuations
    @Environment(\.modelContext) private var modelContext
    @Query private var cards: [UserCard]

    var body: some View {
        let cheatSheet = CheatSheetBuilder.make(
            cards: cards.sorted { $0.sortOrder < $1.sortOrder }.map(\.rewards),
            goal: settings.goal,
            valuations: settings.valuations
        )
        TabView {
            Tab("Nearby", systemImage: "location.fill") {
                NearbyView()
            }
            Tab("Search", systemImage: "magnifyingglass") {
                SearchView()
            }
            Tab("My Cards", systemImage: "creditcard.fill") {
                MyCardsView()
            }
            Tab("Settings", systemImage: "gearshape.fill") {
                SettingsView()
            }
        }
        .fullScreenCover(isPresented: .constant(!hasOnboarded)) {
            OnboardingView { hasOnboarded = true }
        }
        .task {
            catalog.sync(cards)
            if await catalog.refresh() {
                catalog.sync(cards)
            }
            if await valuations.refresh() {
                valuations.apply(to: settings)
            }
        }
        .task(id: cheatSheet) {
            CheatSheetBuilder.publish(cheatSheet)
        }
    }
}

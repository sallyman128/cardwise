import SwiftData
import SwiftUI

@main
struct CardWiseApp: App {
    @State private var settings = AppSettings()
    @State private var catalog: CatalogStore
    private let container: ModelContainer

    init() {
        let catalog = CatalogStore()
        do {
            container = try ModelContainer(for: UserCard.self)
        } catch {
            fatalError("Couldn't open the card database: \(error)")
        }
        #if DEBUG
        DemoData.seedIfRequested(into: container.mainContext, catalog: catalog)
        #endif
        _catalog = State(initialValue: catalog)
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(settings)
                .environment(catalog)
        }
        .modelContainer(container)
    }
}

#if DEBUG
/// Launch with `-demo` to skip onboarding with three sample cards (used for simulator checks).
enum DemoData {
    static func seedIfRequested(into context: ModelContext, catalog: CatalogStore) {
        guard ProcessInfo.processInfo.arguments.contains("-demo") else { return }
        let existing = (try? context.fetchCount(FetchDescriptor<UserCard>())) ?? 0
        guard existing == 0 else { return }
        for (index, id) in ["amex-gold", "chase-sapphire-preferred", "citi-double-cash"].enumerated() {
            if let card = catalog.catalog.card(id: id) {
                context.insert(UserCard(catalogCard: card, asOf: catalog.catalog.asOf, sortOrder: index))
            }
        }
        UserDefaults.standard.set(true, forKey: RootView.onboardedKey)
    }
}
#endif

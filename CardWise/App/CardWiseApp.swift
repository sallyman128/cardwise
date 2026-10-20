import SwiftData
import SwiftUI

@main
struct CardWiseApp: App {
    @State private var settings: AppSettings
    @State private var catalog: CatalogStore
    @State private var valuations: ValuationStore
    @State private var arrivals: ArrivalMonitor
    private let container: ModelContainer

    init() {
        let settings = AppSettings()
        let catalog = CatalogStore()
        let valuations = ValuationStore()
        valuations.apply(to: settings)
        do {
            container = try ModelContainer(for: UserCard.self)
        } catch {
            fatalError("Couldn't open the card database: \(error)")
        }
        #if DEBUG
        DemoData.seedIfRequested(into: container.mainContext, catalog: catalog)
        #endif
        // Set up before launch finishes so background relaunches from a visit get delivered.
        let arrivals = ArrivalMonitor(container: container, directory: catalog.directory, settings: settings)
        arrivals.start()
        _settings = State(initialValue: settings)
        _catalog = State(initialValue: catalog)
        _valuations = State(initialValue: valuations)
        _arrivals = State(initialValue: arrivals)
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(settings)
                .environment(catalog)
                .environment(valuations)
                .environment(arrivals)
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

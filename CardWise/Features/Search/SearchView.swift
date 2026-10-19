import SwiftUI

struct SearchView: View {
    @State private var query = ""
    @Environment(CatalogStore.self) private var catalog

    private static let popularIDs = [
        "amazon", "doordash", "ubereats", "uber", "netflix", "target",
        "walmart", "instacart", "airbnb", "delta", "costco", "spotify",
    ]

    var body: some View {
        NavigationStack {
            List {
                if query.isEmpty {
                    popularSection
                    categorySection(title: "Browse by category")
                } else {
                    let results = catalog.directory.search(query)
                    if !results.isEmpty {
                        Section("Merchants") {
                            ForEach(results) { merchant in
                                NavigationLink(value: PurchaseContext(merchant: merchant)) {
                                    MerchantRow(merchant: merchant)
                                }
                            }
                        }
                    }
                    categorySection(title: results.isEmpty ? "Not listed? Choose a category" : "Or choose a category")
                }
            }
            .navigationTitle("Search")
            .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: "Store, website or app")
            .autocorrectionDisabled()
            .navigationDestination(for: PurchaseContext.self) { purchase in
                RecommendationScreen(purchase: purchase)
            }
        }
    }

    private var popularSection: some View {
        Section("Popular") {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(Self.popularIDs.compactMap(catalog.directory.merchant(id:))) { merchant in
                        NavigationLink(value: PurchaseContext(merchant: merchant)) {
                            Label(merchant.name, systemImage: merchant.category.symbol)
                                .font(.subheadline.weight(.medium))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(.tint.opacity(0.12), in: .capsule)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 4)
            }
            .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
        }
    }

    private func categorySection(title: String) -> some View {
        Section(title) {
            ForEach(SpendCategory.allCases) { category in
                NavigationLink(value: PurchaseContext(category: category)) {
                    Label(category.displayName, systemImage: category.symbol)
                }
            }
        }
    }
}

private struct MerchantRow: View {
    let merchant: Merchant

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: merchant.category.symbol)
                .frame(width: 28)
                .foregroundStyle(.tint)
            VStack(alignment: .leading, spacing: 1) {
                Text(merchant.name)
                Text(merchant.category.displayName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

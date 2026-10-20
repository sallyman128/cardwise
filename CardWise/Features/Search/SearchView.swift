import SwiftData
import SwiftUI

struct SearchView: View {
    @State private var query = ""
    @Environment(CatalogStore.self) private var catalog
    @Environment(AppSettings.self) private var settings
    @Query(sort: \UserCard.sortOrder) private var cards: [UserCard]

    private static let popularIDs = [
        "amazon", "doordash", "ubereats", "uber", "netflix", "target",
        "walmart", "instacart", "airbnb", "delta", "costco", "spotify",
    ]

    var body: some View {
        NavigationStack {
            List {
                if query.isEmpty {
                    popularSection
                    categorySection(title: "Best card by category")
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
        let rewards = cards.map(\.rewards)
        return Section {
            ForEach(SpendCategory.allCases) { category in
                let best = RecommendationEngine.rank(
                    rewards, for: PurchaseContext(category: category),
                    goal: settings.goal, valuations: settings.valuations
                ).first
                NavigationLink(value: PurchaseContext(category: category)) {
                    CategoryRow(category: category, best: best)
                }
            }
        } header: {
            Text(title)
        } footer: {
            if !cards.isEmpty {
                Text("Based on your goal: \(settings.goal.title). Tap a category to compare all your cards.")
            }
        }
    }
}

/// A category with the best card for it, like the widget shows.
private struct CategoryRow: View {
    let category: SpendCategory
    let best: Recommendation?

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: category.symbol)
                .frame(width: 28)
                .foregroundStyle(.tint)
            Text(category.displayName)
            Spacer(minLength: 8)
            if let best {
                HStack(spacing: 8) {
                    VStack(alignment: .trailing, spacing: 1) {
                        Text(best.card.name)
                            .font(.subheadline.weight(.medium))
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                        Text(Self.rate(best))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(Color(hex: best.card.colorHex).gradient)
                        .frame(width: 26, height: 16)
                }
                .layoutPriority(1)
            }
        }
        .accessibilityElement(children: .combine)
    }

    /// "4x · 8¢" for points, "3%" for cash back.
    private static func rate(_ recommendation: Recommendation) -> String {
        let rate = RecommendationEngine.format(recommendation.rate)
        if recommendation.card.currency.isCashBack { return "\(rate)%" }
        return "\(rate)x · \(RecommendationEngine.format(recommendation.centsPerDollar))¢"
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

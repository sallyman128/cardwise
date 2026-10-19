import SwiftUI

/// Pick one or more cards from the catalog. Cards already owned are shown but can't be picked again.
struct CatalogPickerView: View {
    let ownedIDs: Set<String>
    var title = "Add Cards"
    var confirmTitle: (Int) -> String = { count in
        switch count {
        case 0: "Select Cards"
        case 1: "Add 1 Card"
        default: "Add \(count) Cards"
        }
    }
    let onConfirm: ([CatalogCard]) -> Void

    @Environment(CatalogStore.self) private var catalog
    @State private var selected = Set<String>()
    @State private var query = ""

    private var issuers: [(issuer: String, cards: [CatalogCard])] {
        let needle = MerchantDirectory.normalize(query)
        let matching = catalog.catalog.cards.filter { card in
            needle.isEmpty || MerchantDirectory.normalize("\(card.issuer) \(card.name)").contains(needle)
        }
        return Dictionary(grouping: matching, by: \.issuer)
            .map { ($0.key, $0.value.sorted { $0.name < $1.name }) }
            .sorted { $0.issuer < $1.issuer }
    }

    var body: some View {
        List {
            ForEach(issuers, id: \.issuer) { group in
                Section(group.issuer) {
                    ForEach(group.cards) { card in
                        row(card)
                    }
                }
            }
            Section {
            } footer: {
                Text("Rates as of \(catalog.catalog.asOfDisplay). You can edit any card after adding it.")
            }
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $query, prompt: "Search cards")
        .safeAreaInset(edge: .bottom) {
            Button {
                onConfirm(catalog.catalog.cards.filter { selected.contains($0.id) })
            } label: {
                Text(confirmTitle(selected.count))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(selected.isEmpty)
            .padding()
            .background(.bar)
        }
    }

    private func row(_ card: CatalogCard) -> some View {
        let owned = ownedIDs.contains(card.id)
        let isSelected = selected.contains(card.id)
        return Button {
            if isSelected { selected.remove(card.id) } else { selected.insert(card.id) }
        } label: {
            HStack(spacing: 14) {
                CardArtView(card)
                VStack(alignment: .leading, spacing: 2) {
                    Text(card.name)
                        .foregroundStyle(.primary)
                    Text(card.annualFee == 0 ? "No annual fee" : "$\(card.annualFee) annual fee")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if owned {
                    Text("Added")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.title3)
                        .foregroundStyle(isSelected ? AnyShapeStyle(.tint) : AnyShapeStyle(.tertiary))
                }
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .disabled(owned)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

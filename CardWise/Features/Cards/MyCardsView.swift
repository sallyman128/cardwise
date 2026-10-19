import SwiftData
import SwiftUI

struct MyCardsView: View {
    @Query(sort: \UserCard.sortOrder) private var cards: [UserCard]
    @Environment(\.modelContext) private var modelContext
    @Environment(CatalogStore.self) private var catalog
    @State private var showingCatalog = false
    @State private var newCustomCard: UserCard?

    var body: some View {
        NavigationStack {
            Group {
                if cards.isEmpty {
                    ContentUnavailableView {
                        Label("No cards yet", systemImage: "creditcard")
                    } description: {
                        Text("Add the credit cards you carry. CardWise only stores the card type and its rewards, never card numbers.")
                    } actions: {
                        Button("Add a Card") { showingCatalog = true }
                            .buttonStyle(.borderedProminent)
                    }
                } else {
                    List {
                        ForEach(cards) { card in
                            NavigationLink(value: card) {
                                CardRow(card: card)
                            }
                        }
                        .onDelete(perform: delete)
                        .onMove(perform: move)
                    }
                }
            }
            .navigationTitle("My Cards")
            .navigationDestination(for: UserCard.self) { card in
                CardEditorView(card: card)
            }
            .toolbar {
                if !cards.isEmpty {
                    ToolbarItem(placement: .topBarLeading) { EditButton() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Menu("Add", systemImage: "plus") {
                        Button("From Card List", systemImage: "list.bullet") { showingCatalog = true }
                        Button("Custom Card", systemImage: "square.and.pencil") { addCustomCard() }
                    }
                }
            }
            .sheet(isPresented: $showingCatalog) {
                NavigationStack {
                    CatalogPickerView(ownedIDs: Set(cards.compactMap(\.catalogID))) { picked in
                        add(picked)
                        showingCatalog = false
                    }
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Cancel") { showingCatalog = false }
                        }
                    }
                }
            }
            .sheet(item: $newCustomCard) { card in
                NavigationStack {
                    CardEditorView(card: card)
                        .toolbar {
                            ToolbarItem(placement: .confirmationAction) {
                                Button("Done") { newCustomCard = nil }
                            }
                        }
                }
            }
        }
    }

    private func add(_ picked: [CatalogCard]) {
        let start = (cards.map(\.sortOrder).max() ?? -1) + 1
        for (offset, card) in picked.enumerated() {
            modelContext.insert(UserCard(catalogCard: card, asOf: catalog.catalog.asOf, sortOrder: start + offset))
        }
    }

    private func addCustomCard() {
        let card = UserCard(customNamed: "My Card", sortOrder: (cards.map(\.sortOrder).max() ?? -1) + 1)
        modelContext.insert(card)
        newCustomCard = card
    }

    private func delete(at offsets: IndexSet) {
        offsets.map { cards[$0] }.forEach(modelContext.delete)
    }

    private func move(from source: IndexSet, to destination: Int) {
        var reordered = cards
        reordered.move(fromOffsets: source, toOffset: destination)
        for (index, card) in reordered.enumerated() {
            card.sortOrder = index
        }
    }
}

private struct CardRow: View {
    let card: UserCard

    var body: some View {
        HStack(spacing: 14) {
            CardArtView(card)
            VStack(alignment: .leading, spacing: 2) {
                Text(card.displayName)
                    .font(.body.weight(.medium))
                Text(card.currency.displayName)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if card.catalogID != nil, !card.followsCatalog {
                Text("Edited")
                    .font(.caption2.weight(.semibold))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(.fill.tertiary, in: .capsule)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }
}

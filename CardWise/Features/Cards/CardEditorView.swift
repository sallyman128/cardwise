import SwiftData
import SwiftUI

/// View and edit one card's rewards. Changing a rate on a catalog card stops it
/// following catalog updates until it's reset.
struct CardEditorView: View {
    @Bindable var card: UserCard

    @Environment(CatalogStore.self) private var catalog
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var confirmingDelete = false

    private var isCustom: Bool { card.catalogID == nil }
    private var unit: String { card.currency.isCashBack ? "%" : "x" }

    var body: some View {
        Form {
            Section {
                CardArtView(card, size: .large)
                    .frame(maxWidth: .infinity)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
            }

            if !isCustom { termsSection }

            Section("Card") {
                if isCustom {
                    TextField("Name", text: $card.name)
                    TextField("Issuer", text: $card.issuer)
                } else {
                    LabeledContent("Card", value: card.name)
                    LabeledContent("Issuer", value: card.issuer)
                }
                TextField("Nickname (optional)", text: Binding(
                    get: { card.nickname ?? "" },
                    set: { card.nickname = $0.isEmpty ? nil : $0 }
                ))
                Picker("Rewards", selection: Binding(
                    get: { card.currency },
                    set: { newValue in edit { card.currency = newValue } }
                )) {
                    ForEach(RewardCurrency.allCases) { currency in
                        Text(currency.displayName).tag(currency)
                    }
                }
                RateField(title: "Everything else", unit: unit, value: Binding(
                    get: { card.baseRate },
                    set: { newValue in
                        guard let newValue, newValue != card.baseRate else { return }
                        edit { card.baseRate = newValue }
                    }
                ))
            }

            Section {
                ForEach(SpendCategory.allCases.filter { $0 != .other }) { category in
                    RateField(title: category.displayName, symbol: category.symbol, unit: unit, value: categoryRate(category))
                }
            } header: {
                Text("Category rates")
            } footer: {
                Text("Leave blank to earn the base rate. Flights, hotels, rideshare and transit also earn the Travel rate if it's higher.")
            }

            if !card.merchantRates.isEmpty {
                Section("Merchant rates") {
                    ForEach(card.merchantRates.keys.sorted(), id: \.self) { id in
                        RateField(
                            title: catalog.directory.merchant(id: id)?.name ?? id,
                            unit: unit,
                            value: merchantRate(id)
                        )
                    }
                }
            }

            bonusSection

            Section("Notes") {
                if isCustom {
                    TextField("Caps, exclusions, reminders…", text: $card.notes, axis: .vertical)
                } else if !card.notes.isEmpty {
                    Text(card.notes)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }

            Section {
                Button("Remove Card", role: .destructive) { confirmingDelete = true }
            }
        }
        .navigationTitle(card.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog("Remove \(card.displayName)?", isPresented: $confirmingDelete, titleVisibility: .visible) {
            Button("Remove Card", role: .destructive) {
                let card = card
                dismiss()
                modelContext.delete(card)
            }
        }
    }

    @ViewBuilder
    private var termsSection: some View {
        Section {
            if card.followsCatalog {
                Label("Using the latest terms (as of \(catalog.catalog.asOfDisplay))", systemImage: "checkmark.seal")
                    .foregroundStyle(.secondary)
            } else {
                Label("You edited this card's rates, so it no longer updates automatically.", systemImage: "pencil.circle")
                    .foregroundStyle(.secondary)
                if let id = card.catalogID, let latest = catalog.catalog.card(id: id) {
                    Button("Reset to Latest Terms") {
                        card.apply(latest, asOf: catalog.catalog.asOf)
                    }
                }
            }
        }
        .font(.callout)
    }

    @ViewBuilder
    private var bonusSection: some View {
        if card.bonusRate > 0 || isCustom {
            Section {
                if isCustom {
                    RateField(title: "Bonus rate", unit: unit, value: Binding(
                        get: { card.bonusRate > 0 ? card.bonusRate : nil },
                        set: { card.bonusRate = $0 ?? 0 }
                    ))
                }
                if card.bonusRate > 0 {
                    ForEach(SpendCategory.allCases.filter { $0 != .other }) { category in
                        Toggle(isOn: Binding(
                            get: { card.bonusCategories.contains(category) },
                            set: { isOn in
                                var chosen = card.bonusCategories
                                if isOn { chosen.insert(category) } else { chosen.remove(category) }
                                card.bonusCategories = chosen
                            }
                        )) {
                            Label(category.displayName, systemImage: category.symbol)
                        }
                    }
                }
            } header: {
                Text(card.bonusRate > 0 ? "\(RecommendationEngine.format(card.bonusRate))\(unit) bonus categories" : "Bonus categories")
            } footer: {
                Text(card.bonusLabel.map { "\($0). Turn on the categories that earn the bonus right now." }
                     ?? "For rotating or pick-your-own categories. Set a rate, then choose the categories.")
            }
        }
    }

    /// Applies a rate change and stops this card from following catalog updates.
    private func edit(_ change: () -> Void) {
        change()
        card.followsCatalog = false
    }

    private func categoryRate(_ category: SpendCategory) -> Binding<Double?> {
        Binding(
            get: { card.categoryRates[category] },
            set: { newValue in
                guard newValue != card.categoryRates[category] else { return }
                edit {
                    var rates = card.categoryRates
                    rates[category] = newValue
                    card.categoryRates = rates
                }
            }
        )
    }

    private func merchantRate(_ id: String) -> Binding<Double?> {
        Binding(
            get: { card.merchantRates[id] },
            set: { newValue in
                guard newValue != card.merchantRates[id] else { return }
                edit {
                    var rates = card.merchantRates
                    rates[id] = newValue
                    card.merchantRates = rates
                }
            }
        )
    }
}

private struct RateField: View {
    let title: String
    var symbol: String?
    let unit: String
    @Binding var value: Double?

    var body: some View {
        HStack {
            if let symbol {
                Label(title, systemImage: symbol)
            } else {
                Text(title)
            }
            Spacer()
            TextField("—", value: $value, format: .number)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .frame(width: 64)
            Text(unit)
                .foregroundStyle(.secondary)
                .frame(width: 16, alignment: .leading)
        }
    }
}

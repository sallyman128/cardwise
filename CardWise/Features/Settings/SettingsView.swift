import SwiftData
import SwiftUI

struct SettingsView: View {
    @Environment(AppSettings.self) private var settings
    @Environment(CatalogStore.self) private var catalog
    @Query private var cards: [UserCard]

    var body: some View {
        @Bindable var settings = settings
        NavigationStack {
            Form {
                GoalPicker(goal: $settings.goal)

                ArrivalAlertsSection()

                Section {
                    ForEach(RewardCurrency.allCases.filter { !$0.isCashBack }) { currency in
                        ValuationRow(currency: currency, valuations: $settings.valuations)
                    }
                    if !settings.valuations.overrides.isEmpty {
                        Button("Reset to Defaults") { settings.valuations = Valuations() }
                    }
                } header: {
                    Text("Point values (¢ per point)")
                } footer: {
                    Text("Used to compare points with cash back. Travel values assume transferring to partners, which some programs only allow with a premium card. Cash back is always 1¢ per percent.")
                }

                Section {
                    LabeledContent("Rates as of", value: catalog.catalog.asOfDisplay)
                    LabeledContent("Source", value: catalog.source == .downloaded ? "Downloaded update" : "Built into app")
                    Button {
                        Task {
                            if await catalog.refresh() { catalog.sync(cards) }
                        }
                    } label: {
                        HStack {
                            Text("Check for Updates")
                            Spacer()
                            statusView
                        }
                    }
                    .disabled(catalog.status == .checking)
                } header: {
                    Text("Card terms")
                } footer: {
                    Text("CardWise checks for updated card terms each time it opens. Cards you've edited keep your changes.")
                }

                Section {
                    Label("Your cards, settings and location stay on this iPhone. CardWise never asks for card numbers.", systemImage: "lock.shield")
                        .font(.callout)
                    Label("Reward rates are a guide. Check your card's terms for caps and exclusions.", systemImage: "info.circle")
                        .font(.callout)
                } header: {
                    Text("About")
                }
                .foregroundStyle(.secondary)
            }
            .navigationTitle("Settings")
        }
    }

    @ViewBuilder
    private var statusView: some View {
        switch catalog.status {
        case .idle: EmptyView()
        case .checking: ProgressView()
        case .upToDate: Text("Up to date").foregroundStyle(.secondary)
        case .updated: Text("Updated").foregroundStyle(.green)
        case .failed(let message): Text(message).font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.trailing)
        }
    }
}

/// Goal choice, shared by Settings and onboarding.
struct GoalPicker: View {
    @Binding var goal: RewardGoal

    private enum Kind: Hashable { case cash, travel, program }

    private var kind: Binding<Kind> {
        Binding(
            get: {
                switch goal {
                case .maxCash: .cash
                case .maxTravel: .travel
                case .program: .program
                }
            },
            set: { kind in
                switch kind {
                case .cash: goal = .maxCash
                case .travel: goal = .maxTravel
                case .program:
                    if case .program = goal { return }
                    goal = .program(.chaseUR)
                }
            }
        )
    }

    var body: some View {
        Section {
            Picker("Goal", selection: kind) {
                Label("Most cash value", systemImage: "dollarsign.circle").tag(Kind.cash)
                Label("Most travel value", systemImage: "airplane.circle").tag(Kind.travel)
                Label("One points program", systemImage: "star.circle").tag(Kind.program)
            }
            .pickerStyle(.inline)
            .labelsHidden()

            if case .program(let current) = goal {
                Picker("Program", selection: Binding(get: { current }, set: { goal = .program($0) })) {
                    ForEach(RewardCurrency.allCases.filter { !$0.isCashBack }) { currency in
                        Text(currency.displayName).tag(currency)
                    }
                }
            }
        } header: {
            Text("Goal")
        } footer: {
            Text(footer)
        }
    }

    private var footer: String {
        switch goal {
        case .maxCash: "Picks the card worth the most if you redeem for cash or statement credit."
        case .maxTravel: "Picks the card worth the most if you redeem points for travel."
        case .program(let currency): "Puts cards earning \(currency.displayName) first, then the best of the rest."
        }
    }
}

private struct ValuationRow: View {
    let currency: RewardCurrency
    @Binding var valuations: Valuations

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(currency.displayName)
            HStack(spacing: 16) {
                field("Cash", \.cash)
                field("Travel", \.travel)
            }
            .font(.subheadline)
        }
        .padding(.vertical, 2)
    }

    private func field(_ title: String, _ keyPath: WritableKeyPath<Valuation, Double>) -> some View {
        HStack(spacing: 4) {
            Text(title).foregroundStyle(.secondary)
            TextField(title, value: Binding(
                get: { valuations.valuation(for: currency)[keyPath: keyPath] },
                set: { newValue in
                    var value = valuations.valuation(for: currency)
                    guard value[keyPath: keyPath] != newValue else { return }
                    value[keyPath: keyPath] = newValue
                    valuations.overrides[currency] = value == currency.defaultValuation ? nil : value
                }
            ), format: .number.precision(.fractionLength(0...2)))
            .keyboardType(.decimalPad)
            .frame(width: 52)
            .textFieldStyle(.roundedBorder)
            Text("¢").foregroundStyle(.secondary)
        }
    }
}

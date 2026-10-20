import SwiftData
import SwiftUI

struct SettingsView: View {
    @Environment(AppSettings.self) private var settings
    @Environment(CatalogStore.self) private var catalog
    @Environment(ValuationStore.self) private var published
    @Query private var cards: [UserCard]

    var body: some View {
        @Bindable var settings = settings
        NavigationStack {
            Form {
                GoalPicker(goal: $settings.goal)

                ArrivalAlertsSection()

                Section {
                    ForEach(RewardCurrency.allCases.filter { !$0.isCashBack }) { currency in
                        ValuationRow(
                            currency: currency,
                            cashBasis: published.published.currencies[currency]?.cashBasis,
                            valuations: $settings.valuations
                        )
                    }
                    if !settings.valuations.overrides.isEmpty {
                        Button("Use Published Values") { settings.valuations.overrides = [:] }
                    }
                    Button {
                        Task {
                            if await published.refresh() { published.apply(to: settings) }
                        }
                    } label: {
                        HStack {
                            Text("Update Point Values")
                            Spacer()
                            StatusText(status: published.status)
                        }
                    }
                    .disabled(published.status == .checking)
                } header: {
                    Text("Point values (¢ per point)")
                } footer: {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Published values as of \(published.published.asOfDisplay). Travel values come from the sources below and assume transferring points to partners, which some programs only allow with a premium card. Cash values are what each program pays when you redeem for cash. Values you edit are marked and kept when new values arrive.")
                        ForEach(published.published.sources, id: \.self) { source in
                            Link(source.name, destination: source.url)
                                .multilineTextAlignment(.leading)
                        }
                    }
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
                            StatusText(status: catalog.status)
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

}

/// Trailing status for an update button.
private struct StatusText: View {
    let status: RefreshStatus

    var body: some View {
        switch status {
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
    let cashBasis: String?
    @Binding var valuations: Valuations

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(currency.displayName)
                if valuations.overrides[currency] != nil {
                    Text("Edited")
                        .font(.caption2.weight(.semibold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.fill.tertiary, in: .capsule)
                        .foregroundStyle(.secondary)
                }
            }
            if let cashBasis {
                Text("Cash: \(cashBasis)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
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
                    valuations.overrides[currency] = value == valuations.baseline(for: currency) ? nil : value
                }
            ), format: .number.precision(.fractionLength(0...2)))
            .keyboardType(.decimalPad)
            .frame(width: 52)
            .textFieldStyle(.roundedBorder)
            Text("¢").foregroundStyle(.secondary)
        }
    }
}

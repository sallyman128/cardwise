import SwiftData
import SwiftUI

/// The ranked cards for a purchase: the best card up top, the rest below.
struct RecommendationList: View {
    let purchase: PurchaseContext

    @Query(sort: \UserCard.sortOrder) private var cards: [UserCard]
    @Environment(AppSettings.self) private var settings

    var body: some View {
        let ranked = RecommendationEngine.rank(
            cards.map(\.rewards), for: purchase, goal: settings.goal, valuations: settings.valuations)

        if let best = ranked.first {
            VStack(spacing: 20) {
                BestCardView(recommendation: best, goal: settings.goal)

                if ranked.count > 1 {
                    VStack(alignment: .leading, spacing: 0) {
                        Text("Other cards")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal)
                            .padding(.bottom, 8)
                        VStack(spacing: 0) {
                            ForEach(Array(ranked.dropFirst().enumerated()), id: \.element.id) { index, recommendation in
                                if index > 0 { Divider().padding(.leading, 84) }
                                RecommendationRow(recommendation: recommendation)
                            }
                        }
                        .background(.background.secondary, in: .rect(cornerRadius: 14))
                    }
                }

                if let note = purchase.merchant?.note {
                    Label(note, systemImage: "info.circle")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 4)
                }
            }
        } else {
            NoCardsView()
        }
    }
}

struct BestCardView: View {
    let recommendation: Recommendation
    let goal: RewardGoal

    var body: some View {
        VStack(spacing: 14) {
            CardArtView(recommendation.card, size: .large)
                .padding(.top, 4)

            VStack(spacing: 6) {
                Text("Use \(recommendation.card.name)")
                    .font(.title2.weight(.bold))
                    .multilineTextAlignment(.center)
                Text(recommendation.rateDescription)
                    .font(.headline)
                    .foregroundStyle(.tint)
                if let value = recommendation.valueDescription {
                    Text(value)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            Label(goal.title, systemImage: "target")
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(.fill.tertiary, in: .capsule)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }
}

struct RecommendationRow: View {
    let recommendation: Recommendation

    var body: some View {
        HStack(spacing: 14) {
            CardArtView(recommendation.card)
            VStack(alignment: .leading, spacing: 2) {
                Text(recommendation.card.name)
                    .font(.body.weight(.medium))
                Text(recommendation.rateDescription)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 8)
            VStack(alignment: .trailing, spacing: 0) {
                Text("\(RecommendationEngine.format(recommendation.centsPerDollar))¢")
                    .font(.headline.monospacedDigit())
                Text("per $1")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
        .accessibilityElement(children: .combine)
    }
}

struct NoCardsView: View {
    var body: some View {
        ContentUnavailableView {
            Label("No cards yet", systemImage: "creditcard")
        } description: {
            Text("Add the cards in your wallet on the My Cards tab to get suggestions.")
        }
    }
}

/// A full screen of recommendations for a merchant or category, pushed from Search.
struct RecommendationScreen: View {
    let purchase: PurchaseContext

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                Label(purchase.category.displayName, systemImage: purchase.category.symbol)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
                RecommendationList(purchase: purchase)
            }
            .padding()
        }
        .navigationTitle(purchase.title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

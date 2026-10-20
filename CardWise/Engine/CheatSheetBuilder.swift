import Foundation
import WidgetKit

/// Builds the per-category cheat sheet the widget shows, and publishes it to the shared app group.
enum CheatSheetBuilder {
    /// The categories shown on the widget, in display order, with shorter widget titles.
    static let categories: [(category: SpendCategory, title: String)] = [
        (.dining, "Dining"),
        (.groceries, "Groceries"),
        (.gas, "Gas"),
        (.travel, "Travel"),
        (.onlineShopping, "Online"),
        (.drugstores, "Drugstores"),
        (.streaming, "Streaming"),
        (.other, "Everything else"),
    ]

    static func make(cards: [CardRewards], goal: RewardGoal, valuations: Valuations) -> CheatSheet {
        let rows: [CheatSheet.Row] = categories.compactMap { entry in
            let ranked = RecommendationEngine.rank(
                cards, for: PurchaseContext(category: entry.category), goal: goal, valuations: valuations)
            guard let best = ranked.first else { return nil }
            let rate = RecommendationEngine.format(best.rate) + (best.card.currency.isCashBack ? "%" : "x")
            return CheatSheet.Row(
                id: entry.category.rawValue,
                title: entry.title,
                symbol: entry.category.symbol,
                cardName: best.card.name,
                rate: rate,
                colorHex: best.card.colorHex
            )
        }
        return CheatSheet(goalTitle: goal.title, rows: rows)
    }

    /// Saves the sheet for the widget and asks WidgetKit to redraw, but only when it changed.
    static func publish(_ sheet: CheatSheet) {
        guard sheet != CheatSheet.load() else { return }
        sheet.save()
        WidgetCenter.shared.reloadAllTimelines()
    }
}

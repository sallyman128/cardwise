import Testing
@testable import CardWise

struct CheatSheetTests {
    let gold = card("Gold", .amexMR, base: 1, rates: [.dining: 4, .groceries: 4])
    let doubleCash = card("Double Cash", .cashBack, base: 2)

    @Test func picksBestCardPerCategory() {
        let sheet = CheatSheetBuilder.make(cards: [gold, doubleCash], goal: .maxTravel, valuations: Valuations())
        let byID = Dictionary(uniqueKeysWithValues: sheet.rows.map { ($0.id, $0) })

        #expect(sheet.rows.count == CheatSheetBuilder.categories.count)
        #expect(byID["dining"]?.cardName == "Gold")
        #expect(byID["dining"]?.rate == "4x")
        #expect(byID["gas"]?.cardName == "Double Cash")
        #expect(byID["gas"]?.rate == "2%")
        #expect(sheet.goalTitle == "Most travel value")
    }

    @Test func emptyWithoutCards() {
        let sheet = CheatSheetBuilder.make(cards: [], goal: .maxCash, valuations: Valuations())
        #expect(sheet.rows.isEmpty)
    }
}

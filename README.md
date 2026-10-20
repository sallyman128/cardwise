# CardWise

An iOS app that tells you which of your credit cards to use for a purchase, based on your goal: most cash value, most travel value, or the most points in one program.

- **Nearby:** finds the place you're at with Apple Maps and suggests a card for it.
- **Search:** look up a store, website or app (Amazon, DoorDash, Costco…) or browse by category.
- **My Cards:** pick your cards from the built-in list, or add custom ones. No card numbers are stored.
- **Settings:** choose your goal and how much each points program is worth to you.

Everything stays on the phone. There are no accounts and no server.

## Running it

Requires Xcode 26 or later and [XcodeGen](https://github.com/yonaskolb/XcodeGen). The Xcode project is generated, not committed.

```bash
xcodegen generate
```

```bash
open CardWise.xcodeproj
```

Run the tests from the command line:

```bash
xcodebuild test -project CardWise.xcodeproj -scheme CardWise -destination 'platform=iOS Simulator,name=iPhone 17'
```

In Debug builds, launching with the `-demo` argument skips onboarding and adds three sample cards.

## Updating card terms

Card rates live in [`CardWise/Data/cards.json`](CardWise/Data/cards.json). Each time the app opens, it downloads that file from this repo's `main` branch on GitHub (see `HostedFile`). If the downloaded copy is newer, the app uses it and caches it on the phone.

To change rates:

1. Edit `cards.json`.
2. Bump `asOf` to today's date (`yyyy-MM-dd`). The app only switches to a file with a newer date.
3. Commit and push to `main`.

Cards a user has edited keep their changes. Every other card updates automatically.

Point values (cents per point for cash and for travel) work the same way, from [`CardWise/Data/valuations.json`](CardWise/Data/valuations.json). Travel values come from published monthly valuations (The Points Guy, Upgraded Points); cash values are what each program pays when redeemed for cash. A weekly Claude routine refreshes this file, and the app picks it up at launch or from **Update Point Values** in Settings. Values a user edits in Settings are kept.

Merchants and their categories are in [`CardWise/Data/merchants.json`](CardWise/Data/merchants.json). That file ships with the app; updating it requires a new build.

## Layout

| Folder | What's in it |
|---|---|
| `CardWise/Models` | Categories, currencies, goals, catalog and merchant types, the SwiftData `UserCard` |
| `CardWise/Engine` | `RecommendationEngine` (ranks cards) and `CategoryMapper` (Apple Maps place → category) |
| `CardWise/Data` | The bundled JSON and `CatalogStore`, which loads and refreshes it |
| `CardWise/Services` | Location and nearby-place lookups |
| `CardWise/Features` | One folder per tab, plus onboarding |
| `CardWiseTests` | Engine, catalog, merchant matching and category mapping tests |

import Foundation
import Observation
import SwiftData

/// Holds the card catalog and merchant directory.
///
/// The app ships with `cards.json`, then checks the copy hosted in the GitHub repo (see `HostedFile`) on launch.
/// A newer hosted copy is cached on device and used from then on, so rates can be fixed
/// by editing `CardWise/Data/cards.json` and pushing, without shipping an app update.
@Observable
final class CatalogStore {
    enum Source: Equatable {
        case bundled
        case downloaded
    }

    private(set) var catalog: CardCatalog
    private(set) var source: Source
    private(set) var status: RefreshStatus = .idle
    let directory: MerchantDirectory

    private let file: HostedFile

    /// `cacheDirectory` is where downloaded copies are kept; nil turns caching off (for tests).
    init(bundle: Bundle = .main, cacheDirectory: URL? = HostedFile.defaultCacheURL) {
        let bundled = Self.loadBundledCatalog(from: bundle)
        file = HostedFile(name: "cards", cacheURL: cacheDirectory)
        directory = MerchantDirectory(merchants: Self.loadMerchants(from: bundle))

        if let data = file.cached(),
           let cached = try? Self.decodeCatalog(data),
           Self.isNewer(cached, than: bundled) {
            catalog = cached
            source = .downloaded
        } else {
            catalog = bundled
            source = .bundled
        }
    }

    /// Downloads the hosted catalog and switches to it when it's newer than what we have.
    /// Returns true when the catalog changed.
    @discardableResult
    func refresh(session: URLSession = .shared) async -> Bool {
        status = .checking
        do {
            let data = try await file.fetch(session: session)
            let remote = try Self.decodeCatalog(data)
            guard Self.isNewer(remote, than: catalog) else {
                status = .upToDate
                return false
            }
            file.cache(data)
            catalog = remote
            source = .downloaded
            status = .updated
            return true
        } catch {
            status = RefreshStatus(error: error)
            return false
        }
    }

    /// Brings cards that follow the catalog up to the current terms.
    func sync(_ cards: [UserCard]) {
        for card in cards where card.followsCatalog && card.syncedAsOf != catalog.asOf {
            guard let id = card.catalogID, let latest = catalog.card(id: id) else { continue }
            card.apply(latest, asOf: catalog.asOf)
        }
    }

    // MARK: - Loading

    nonisolated static func decodeCatalog(_ data: Data) throws -> CardCatalog {
        let catalog = try JSONDecoder().decode(CardCatalog.self, from: data)
        guard catalog.schemaVersion <= CardCatalog.supportedSchemaVersion, !catalog.cards.isEmpty else {
            throw DecodingError.dataCorrupted(.init(codingPath: [], debugDescription: "Unsupported catalog"))
        }
        return catalog
    }

    /// `asOf` is an ISO date, so plain string comparison orders it correctly.
    nonisolated static func isNewer(_ candidate: CardCatalog, than current: CardCatalog) -> Bool {
        candidate.asOf > current.asOf
    }

    nonisolated static func loadBundledCatalog(from bundle: Bundle) -> CardCatalog {
        guard let data = HostedFile(name: "cards", cacheURL: nil).bundled(in: bundle),
              let catalog = try? decodeCatalog(data) else {
            assertionFailure("cards.json is missing or invalid")
            return CardCatalog(schemaVersion: CardCatalog.supportedSchemaVersion, asOf: "", cards: [])
        }
        return catalog
    }

    nonisolated static func loadMerchants(from bundle: Bundle) -> [Merchant] {
        guard let url = bundle.url(forResource: "merchants", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let merchants = try? JSONDecoder().decode([Merchant].self, from: data) else {
            assertionFailure("merchants.json is missing or invalid")
            return []
        }
        return merchants
    }
}

extension CardCatalog {
    /// "Oct 19, 2026" for display.
    var asOfDisplay: String {
        let parser = DateFormatter()
        parser.locale = Locale(identifier: "en_US_POSIX")
        parser.dateFormat = "yyyy-MM-dd"
        guard let date = parser.date(from: asOf) else { return asOf }
        return date.formatted(date: .abbreviated, time: .omitted)
    }
}

import Foundation
import Observation
import SwiftData

/// Holds the card catalog and merchant directory.
///
/// The app ships with `cards.json`, then checks the copy hosted in the GitHub repo on launch.
/// A newer hosted copy is cached on device and used from then on, so rates can be fixed
/// by editing `CardWise/Data/cards.json` and pushing, without shipping an app update.
@Observable
final class CatalogStore {
    static let remoteURL = URL(string: "https://raw.githubusercontent.com/sallyman128/cardwise/main/CardWise/Data/cards.json")!

    enum Source: Equatable {
        case bundled
        case downloaded
    }

    enum RefreshStatus: Equatable {
        case idle
        case checking
        case upToDate
        case updated
        case failed(String)
    }

    private(set) var catalog: CardCatalog
    private(set) var source: Source
    private(set) var status: RefreshStatus = .idle
    let directory: MerchantDirectory

    private let cacheURL: URL?

    init(bundle: Bundle = .main, cacheURL: URL? = CatalogStore.defaultCacheURL) {
        let bundled = Self.loadBundledCatalog(from: bundle)
        self.cacheURL = cacheURL
        self.directory = MerchantDirectory(merchants: Self.loadMerchants(from: bundle))

        if let cacheURL,
           let data = try? Data(contentsOf: cacheURL),
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
            var request = URLRequest(url: Self.remoteURL, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 10)
            request.setValue("application/json", forHTTPHeaderField: "Accept")
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                status = .failed("The hosted card list isn't available yet.")
                return false
            }
            let remote = try Self.decodeCatalog(data)
            guard Self.isNewer(remote, than: catalog) else {
                status = .upToDate
                return false
            }
            if let cacheURL {
                try? FileManager.default.createDirectory(at: cacheURL.deletingLastPathComponent(), withIntermediateDirectories: true)
                try? data.write(to: cacheURL, options: .atomic)
            }
            catalog = remote
            source = .downloaded
            status = .updated
            return true
        } catch is DecodingError {
            status = .failed("The hosted card list couldn't be read.")
            return false
        } catch {
            status = .failed("Couldn't reach the server.")
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

    static let defaultCacheURL: URL? = FileManager.default
        .urls(for: .applicationSupportDirectory, in: .userDomainMask).first?
        .appending(path: "catalog/cards.json")

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
        guard let url = bundle.url(forResource: "cards", withExtension: "json"),
              let data = try? Data(contentsOf: url),
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

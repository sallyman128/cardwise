import Foundation
import Observation

/// Published point values: what each program's points are worth for cash and for travel.
nonisolated struct PublishedValuations: Codable, Sendable {
    struct Source: Codable, Hashable, Sendable {
        let name: String
        let url: URL
    }

    struct Entry: Codable, Hashable, Sendable {
        let cash: Double
        let travel: Double
        /// How the cash value is reached, e.g. "Statement credit".
        let cashBasis: String
    }

    let schemaVersion: Int
    /// ISO date (yyyy-MM-dd). Newer files win.
    let asOf: String
    let sources: [Source]
    let currencies: [RewardCurrency: Entry]

    static let supportedSchemaVersion = 1

    var values: [RewardCurrency: Valuation] {
        currencies.mapValues { Valuation(cash: $0.cash, travel: $0.travel) }
    }

    var asOfDisplay: String {
        let parser = DateFormatter()
        parser.locale = Locale(identifier: "en_US_POSIX")
        parser.dateFormat = "yyyy-MM-dd"
        guard let date = parser.date(from: asOf) else { return asOf }
        return date.formatted(date: .abbreviated, time: .omitted)
    }
}

/// Holds the published point values. The app ships with `valuations.json`; a weekly
/// Claude routine refreshes the hosted copy, which the app downloads at launch or
/// when the user taps Update in Settings.
@Observable
final class ValuationStore {
    private(set) var published: PublishedValuations
    private(set) var status: RefreshStatus = .idle

    private let file: HostedFile

    init(bundle: Bundle = .main, cacheDirectory: URL? = HostedFile.defaultCacheURL) {
        file = HostedFile(name: "valuations", cacheURL: cacheDirectory)
        let bundled = file.bundled(in: bundle).flatMap { try? Self.decode($0) }
        let cached = file.cached().flatMap { try? Self.decode($0) }

        if let cached, let bundled, cached.asOf > bundled.asOf {
            published = cached
        } else if let bundled {
            published = bundled
        } else {
            assertionFailure("valuations.json is missing or invalid")
            published = PublishedValuations(schemaVersion: 1, asOf: "", sources: [], currencies: [:])
        }
    }

    /// Downloads the hosted values and switches to them when they're newer.
    /// Returns true when the values changed.
    @discardableResult
    func refresh(session: URLSession = .shared) async -> Bool {
        status = .checking
        do {
            let data = try await file.fetch(session: session)
            let remote = try Self.decode(data)
            guard remote.asOf > published.asOf else {
                status = .upToDate
                return false
            }
            file.cache(data)
            published = remote
            status = .updated
            return true
        } catch {
            status = RefreshStatus(error: error)
            return false
        }
    }

    /// Hands the current values to the settings the recommendation engine reads.
    func apply(to settings: AppSettings) {
        settings.valuations.published = published.values
    }

    nonisolated static func decode(_ data: Data) throws -> PublishedValuations {
        let decoded = try JSONDecoder().decode(PublishedValuations.self, from: data)
        guard decoded.schemaVersion <= PublishedValuations.supportedSchemaVersion, !decoded.currencies.isEmpty else {
            throw DecodingError.dataCorrupted(.init(codingPath: [], debugDescription: "Unsupported valuations file"))
        }
        return decoded
    }
}

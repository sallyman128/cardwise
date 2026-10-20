import Foundation

/// A JSON file that ships in the app bundle and is also hosted in the GitHub repo.
/// The hosted copy is downloaded on demand and cached on device.
nonisolated struct HostedFile: Sendable {
    /// e.g. "cards" for `CardWise/Data/cards.json`.
    let name: String
    let cacheURL: URL?

    private static let baseURL = URL(string: "https://raw.githubusercontent.com/sallyman128/cardwise/main/CardWise/Data/")!

    init(name: String, cacheURL: URL? = HostedFile.defaultCacheURL) {
        self.name = name
        self.cacheURL = cacheURL?.appending(path: "\(name).json")
    }

    var remoteURL: URL { Self.baseURL.appending(path: "\(name).json") }

    static let defaultCacheURL: URL? = FileManager.default
        .urls(for: .applicationSupportDirectory, in: .userDomainMask).first?
        .appending(path: "hosted")

    enum FetchError: Error {
        case unavailable
    }

    func bundled(in bundle: Bundle) -> Data? {
        bundle.url(forResource: name, withExtension: "json").flatMap { try? Data(contentsOf: $0) }
    }

    func cached() -> Data? {
        cacheURL.flatMap { try? Data(contentsOf: $0) }
    }

    func fetch(session: URLSession = .shared) async throws -> Data {
        var request = URLRequest(url: remoteURL, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 10)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        let (data, response) = try await session.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw FetchError.unavailable }
        return data
    }

    func cache(_ data: Data) {
        guard let cacheURL else { return }
        try? FileManager.default.createDirectory(at: cacheURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? data.write(to: cacheURL, options: .atomic)
    }
}

/// Progress of a "check for updates" on a hosted file, for display in Settings.
enum RefreshStatus: Equatable {
    case idle
    case checking
    case upToDate
    case updated
    case failed(String)

    init(error: Error) {
        switch error {
        case is DecodingError: self = .failed("The hosted file couldn't be read.")
        case HostedFile.FetchError.unavailable: self = .failed("The hosted file isn't available.")
        default: self = .failed("Couldn't reach the server.")
        }
    }
}

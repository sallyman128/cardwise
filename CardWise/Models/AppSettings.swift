import Foundation
import Observation

/// The user's goal and point values, saved in UserDefaults.
@Observable
final class AppSettings {
    var goal: RewardGoal {
        didSet { save(goal, forKey: Keys.goal) }
    }

    var valuations: Valuations {
        didSet { save(valuations, forKey: Keys.valuations) }
    }

    private let defaults: UserDefaults

    private enum Keys {
        static let goal = "goal"
        static let valuations = "valuations"
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        goal = Self.load(RewardGoal.self, forKey: Keys.goal, from: defaults) ?? .maxCash
        valuations = Self.load(Valuations.self, forKey: Keys.valuations, from: defaults) ?? Valuations()
    }

    private func save<T: Encodable>(_ value: T, forKey key: String) {
        defaults.set(try? JSONEncoder().encode(value), forKey: key)
    }

    private static func load<T: Decodable>(_ type: T.Type, forKey key: String, from defaults: UserDefaults) -> T? {
        defaults.data(forKey: key).flatMap { try? JSONDecoder().decode(type, from: $0) }
    }
}

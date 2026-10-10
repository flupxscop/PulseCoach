import Foundation
import FoundationModels
import PulseCore

/// Lets the model pull workout history only when it needs it, which saves the 4K context.
/// Failures return a short sentence instead of throwing, so one bad query can't sink the session.
struct RecentWorkoutsTool: Tool {
    let name = "getRecentWorkouts"
    let description = "Returns the user's workouts from the last N days."

    @Generable
    struct Arguments {
        @Guide(description: "Number of days to look back", .range(1...14))
        var days: Int
    }

    let fetch: @Sendable (Int) async -> [String]

    @MainActor
    init(health: HealthService) {
        fetch = { days in await health.recentWorkoutSummaries(days: days) }
    }

    func call(arguments: Arguments) async throws -> String {
        let items = await fetch(arguments.days)
        return items.isEmpty ? "No workouts recorded." : items.joined(separator: "\n")
    }
}

import Foundation

/// Swappable planners: on-device LLM first, rule-based fallback always available.
public protocol WorkoutPlanner: Sendable {
    func makePlan(profile: UserProfile, readiness: Readiness,
                  recent: [DailyMetrics], startingOn start: Date) async throws -> PlanDTO
}

public enum PlannerError: Error, Sendable {
    case modelUnavailable
}

/// Tries each planner in order and returns the first plan that succeeds,
/// always passed through `SafetyValidator`.
public struct FallbackPlanner: WorkoutPlanner {
    let planners: [any WorkoutPlanner]
    let timeout: Duration

    /// Each planner gets at most `timeout`; a slow or stuck model must never leave the user
    /// staring at a spinner, so it falls through to the next planner.
    public init(_ planners: [any WorkoutPlanner], timeout: Duration = .seconds(20)) {
        self.planners = planners
        self.timeout = timeout
    }

    public func makePlan(profile: UserProfile, readiness: Readiness,
                         recent: [DailyMetrics], startingOn start: Date) async throws -> PlanDTO {
        for planner in planners {
            if let plan = await attempt(planner, profile: profile, readiness: readiness,
                                        recent: recent, start: start) {
                return SafetyValidator.enforce(plan, readiness: readiness)
            }
        }
        let plan = RuleBasedPlanner().makePlan(profile: profile, readiness: readiness, startingOn: start)
        return SafetyValidator.enforce(plan, readiness: readiness)
    }

    private func attempt(_ planner: any WorkoutPlanner, profile: UserProfile, readiness: Readiness,
                         recent: [DailyMetrics], start: Date) async -> PlanDTO? {
        let timeout = timeout
        return await withTaskGroup(of: PlanDTO?.self) { group in
            group.addTask {
                try? await planner.makePlan(profile: profile, readiness: readiness, recent: recent, startingOn: start)
            }
            group.addTask {
                try? await Task.sleep(for: timeout)
                return nil
            }
            let first = await group.next() ?? nil
            group.cancelAll()
            return first
        }
    }
}

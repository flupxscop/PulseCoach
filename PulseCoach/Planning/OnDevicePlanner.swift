import Foundation
import FoundationModels
import PulseCore

// Guided generation: the model fills these structs directly (constrained sampling,
// no JSON parsing). Property order matters: rationale first so the model reasons before planning.

@Generable
enum GenActivity { case rest, walk, run, cycle, strength, hiit, yoga }

@Generable
enum GenIntensity { case easy, moderate, hard }

@Generable(description: "One day of a training plan")
struct GenDayPlan {
    @Guide(description: "Day number in the week", .range(1...7))
    var dayIndex: Int
    var activity: GenActivity
    @Guide(description: "Duration in minutes, 0 for rest", .range(0...90))
    var minutes: Int
    var intensity: GenIntensity
    @Guide(description: "One short coaching tip")
    var tip: String
}

@Generable(description: "A 7-day training plan")
struct GenWeeklyPlan {
    @Guide(description: "Why this plan fits today's readiness, max 2 sentences")
    var rationale: String
    @Guide(.count(7))
    var days: [GenDayPlan]
}

/// iPhone planner on the on-device model: unlimited, offline, 4K context.
/// Throws `modelUnavailable` so `FallbackPlanner` can drop to the rule-based plan.
struct OnDevicePlanner: WorkoutPlanner {
    let health: HealthService

    func makePlan(profile: UserProfile, readiness: Readiness,
                  recent: [DailyMetrics], startingOn start: Date) async throws -> PlanDTO {
        let model = SystemLanguageModel.default
        guard case .available = model.availability else { throw PlannerError.modelUnavailable }

        let thai = Locale(identifier: "th_TH")
        let writesThai = model.supportsLocale(thai)
        let tool = await RecentWorkoutsTool(health: health)

        // Safety rules live in instructions (fixed behaviour), never user-typed text (prompt injection).
        let session = LanguageModelSession(
            model: model,
            tools: [tool],
            instructions: """
            You are a careful fitness coach. Build a safe 7-day plan.
            Rules:
            - If readiness score < 50, day 1 must be rest or an easy walk.
            - Never schedule hard days back to back.
            - At least one rest day per week.
            - Respect the user's goal and available minutes per day.
            Write the rationale and tips in \(writesThai ? "Thai" : "English").
            """
        )

        let prompt = """
        Goal: \(profile.goal.promptName). Level: \(profile.level.rawValue). \
        Active days per week: \(profile.daysPerWeek). Max minutes/day: \(profile.maxMinutes).
        Readiness today: \(readiness.score)/100. Flags: \(readiness.flags.map(\.rawValue)).
        Check recent workouts before planning.
        """

        let response = try await session.respond(to: prompt, generating: GenWeeklyPlan.self)
        return PlanDTO(response.content, start: start, keepModelText: writesThai)
    }
}

extension PlanDTO {
    init(_ generated: GenWeeklyPlan, start: Date, keepModelText: Bool) {
        let days = generated.days.map { d -> DayDTO in
            let activity = ActivityKind(d.activity)
            let intensity = IntensityLevel(d.intensity)
            // When the model can't write Thai, fall back to our pre-translated tips.
            let tip = keepModelText ? d.tip : RuleBasedPlanner.tip(for: activity, intensity)
            return DayDTO(dayIndex: d.dayIndex, activity: activity, minutes: d.minutes,
                          intensity: intensity, tip: tip)
        }
        let rationale = keepModelText ? generated.rationale : "แผนนี้ปรับตามความพร้อมของคุณวันนี้ และพักหลังวันหนักเสมอ"
        self.init(createdAt: start, rationale: rationale, days: days, source: .onDeviceModel)
    }
}

extension ActivityKind {
    init(_ g: GenActivity) {
        self = switch g {
        case .rest: .rest
        case .walk: .walk
        case .run: .run
        case .cycle: .cycle
        case .strength: .strength
        case .hiit: .hiit
        case .yoga: .yoga
        }
    }
}

extension IntensityLevel {
    init(_ g: GenIntensity) {
        self = switch g {
        case .easy: .easy
        case .moderate: .moderate
        case .hard: .hard
        }
    }
}

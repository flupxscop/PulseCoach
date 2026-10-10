import Foundation

/// Deterministic planner used when Apple Intelligence is unavailable.
/// The app must always be able to produce a plan (App Review requirement in the guide).
public struct RuleBasedPlanner: WorkoutPlanner, Sendable {
    public init() {}

    public func makePlan(profile: UserProfile, readiness: Readiness,
                         recent: [DailyMetrics], startingOn start: Date) async throws -> PlanDTO {
        makePlan(profile: profile, readiness: readiness, startingOn: start)
    }

    public func makePlan(profile: UserProfile, readiness: Readiness, startingOn start: Date) -> PlanDTO {
        let template = Self.template(for: profile.goal)
        let restDays = Self.restSlots(activeDays: profile.daysPerWeek)
        var activeQueue = template.makeIterator()

        var days: [DayDTO] = []
        for index in 1...7 {
            if restDays.contains(index) {
                days.append(.rest(dayIndex: index))
                continue
            }
            let slot = activeQueue.next() ?? (.walk, .easy, 30)
            let minutes = min(slot.minutes, profile.maxMinutes)
            days.append(DayDTO(dayIndex: index, activity: slot.activity, minutes: minutes,
                               intensity: slot.intensity, tip: Self.tip(for: slot.activity, slot.intensity)))
        }

        // Day 1 follows today's readiness.
        if readiness.score < 50 {
            days[0] = DayDTO(dayIndex: 1, activity: .walk, minutes: 20, intensity: .easy,
                             tip: "ร่างกายยังฟื้นตัวไม่เต็มที่ เดินเบาๆ พอ")
        } else if readiness.score < 85, days[0].intensity == .hard {
            days[0].intensity = .moderate
        }

        return PlanDTO(createdAt: start, rationale: Self.rationale(profile: profile, readiness: readiness),
                       days: days, source: .ruleBased)
    }

    // MARK: - Templates

    typealias Slot = (activity: ActivityKind, intensity: IntensityLevel, minutes: Int)

    static func template(for goal: FitnessGoal) -> [Slot] {
        switch goal {
        case .getFitter:
            [(.run, .moderate, 35), (.strength, .moderate, 30), (.hiit, .hard, 20),
             (.yoga, .easy, 25), (.cycle, .moderate, 45), (.walk, .easy, 30), (.run, .easy, 30)]
        case .loseWeight:
            [(.walk, .moderate, 40), (.strength, .moderate, 30), (.cycle, .moderate, 40),
             (.hiit, .hard, 20), (.walk, .easy, 45), (.yoga, .easy, 25), (.cycle, .easy, 30)]
        case .buildMuscle:
            [(.strength, .moderate, 40), (.walk, .easy, 30), (.strength, .hard, 45),
             (.yoga, .easy, 25), (.strength, .moderate, 40), (.cycle, .easy, 30), (.strength, .moderate, 35)]
        case .reduceStress:
            [(.yoga, .easy, 30), (.walk, .easy, 30), (.cycle, .easy, 30),
             (.yoga, .easy, 25), (.walk, .moderate, 35), (.yoga, .easy, 20), (.walk, .easy, 25)]
        }
    }

    /// Spreads rest days evenly; day 1 is never a rest slot so "today" has something to do.
    static func restSlots(activeDays: Int) -> Set<Int> {
        let rests = 7 - min(max(activeDays, 3), 7)
        switch rests {
        case 0: return []
        case 1: return [7]
        case 2: return [3, 7]
        case 3: return [3, 5, 7]
        default: return [2, 4, 6, 7]
        }
    }

    public static func tip(for activity: ActivityKind, _ intensity: IntensityLevel) -> String {
        switch activity {
        case .rest: "นอนให้ได้ 7 ชั่วโมงขึ้นไป"
        case .walk: "เดินสบายๆ แกว่งแขนเป็นจังหวะ"
        case .run: intensity == .easy || intensity == .moderate
            ? "วิ่งด้วยความเร็วที่ยังคุยเป็นประโยคได้"
            : "วอร์มอัพ 5 นาทีก่อนเร่งความเร็ว"
        case .cycle: "ปั่นรอบขาสม่ำเสมอ ความเร็วที่ยังคุยได้"
        case .strength: "ท่าหลายข้อต่อ 3 เซ็ต พัก 90 วินาทีระหว่างเซ็ต"
        case .hiit: "วอร์มอัพก่อนเสมอ หยุดทันทีถ้ารู้สึกเวียนหัว"
        case .yoga: "ยืดเหยียดสะโพกและหลัง หายใจช้าๆ"
        }
    }

    static func rationale(profile: UserProfile, readiness: Readiness) -> String {
        let opener: String = switch readiness.score {
        case 85...: "ร่างกายฟื้นตัวดี"
        case 50..<85: "ร่างกายพร้อมระดับหนึ่ง"
        default: "ร่างกายต้องการพัก"
        }
        return "\(opener) แผนนี้เน้น\(profile.goal.title) \(profile.daysPerWeek) วันต่อสัปดาห์ และพักหลังวันหนักเสมอ"
    }
}

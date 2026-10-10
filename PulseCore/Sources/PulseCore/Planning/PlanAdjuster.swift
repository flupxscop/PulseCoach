import Foundation

/// User-driven plan edits from the Plan screen ("เลื่อนไปพรุ่งนี้", "ขอเบาลง").
/// Every edit goes back through `SafetyValidator`, so a user swap can't create two hard days in a row.
public enum PlanAdjuster {
    /// Swaps day `dayIndex` with the following day. The last day can't move forward.
    public static func moveToNextDay(_ plan: PlanDTO, dayIndex: Int, readiness: Readiness) -> PlanDTO {
        guard let i = plan.days.firstIndex(where: { $0.dayIndex == dayIndex }),
              i + 1 < plan.days.count else { return plan }
        var p = plan
        p.days.swapAt(i, i + 1)
        p.days[i].dayIndex = i + 1
        p.days[i + 1].dayIndex = i + 2
        return SafetyValidator.enforce(p, readiness: readiness)
    }

    /// Lowers intensity one step and trims duration by a third, rounded to 5 minutes (minimum 15).
    public static func makeEasier(_ plan: PlanDTO, dayIndex: Int, readiness: Readiness) -> PlanDTO {
        guard let i = plan.days.firstIndex(where: { $0.dayIndex == dayIndex }),
              !plan.days[i].isRest else { return plan }
        var p = plan
        p.days[i].intensity = p.days[i].intensity.lower
        let trimmed = Double(p.days[i].minutes) * 2 / 3
        p.days[i].minutes = max(15, Int((trimmed / 5).rounded()) * 5)
        if p.days[i].activity == .hiit { p.days[i].activity = .cycle }
        return SafetyValidator.enforce(p, readiness: readiness)
    }
}

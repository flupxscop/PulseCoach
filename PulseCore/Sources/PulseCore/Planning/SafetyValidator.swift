import Foundation

/// The last line of defence: rules the code enforces even if the LLM ignores its instructions.
public enum SafetyValidator {
    public static func enforce(_ plan: PlanDTO, readiness: Readiness) -> PlanDTO {
        var p = plan
        // Normalise: exactly days 1...7 in order.
        p.days.sort { $0.dayIndex < $1.dayIndex }
        p.days = Array(p.days.prefix(7))
        for i in p.days.indices { p.days[i].dayIndex = i + 1 }
        while p.days.count < 7 { p.days.append(.rest(dayIndex: p.days.count + 1)) }

        // Rest days carry no load.
        for i in p.days.indices where p.days[i].isRest {
            p.days[i].minutes = 0
            p.days[i].intensity = .easy
        }

        // 1) Low readiness -> day 1 must be easy and short.
        if readiness.score < 50, !p.days[0].isRest {
            p.days[0].intensity = .easy
            p.days[0].minutes = min(p.days[0].minutes, 30)
            if p.days[0].activity == .hiit || p.days[0].activity == .run {
                p.days[0].activity = .walk
            }
        }
        // 2) Never two hard days back to back.
        for i in p.days.indices.dropFirst()
        where p.days[i].intensity == .hard && p.days[i - 1].intensity == .hard {
            p.days[i].intensity = .moderate
        }
        // 3) At least one rest day per week.
        if !p.days.contains(where: \.isRest) {
            p.days[6] = .rest(dayIndex: 7)
        }
        return p
    }
}

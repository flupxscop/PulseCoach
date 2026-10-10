import Foundation

// Pure Swift: no HealthKit, no SwiftUI. Health alerts must be explainable and
// repeatable, so readiness is rule-based against the user's own baseline, never an LLM.
// Wellness scope only: this never diagnoses anything.

public struct Baseline: Sendable, Codable, Equatable {
    public var restingHR: Double?
    public var hrv: Double?

    public init(restingHR: Double? = nil, hrv: Double? = nil) {
        self.restingHR = restingHR
        self.hrv = hrv
    }

    /// Median of the history window (28 days recommended); medians resist outlier days.
    public static func from(history: [DailyMetrics]) -> Baseline {
        Baseline(restingHR: median(history.compactMap(\.restingHR)),
                 hrv: median(history.compactMap(\.hrv)))
    }
}

func median(_ xs: [Double]) -> Double? {
    guard !xs.isEmpty else { return nil }
    let s = xs.sorted(), m = s.count / 2
    return s.count.isMultiple(of: 2) ? (s[m - 1] + s[m]) / 2 : s[m]
}

public enum ReadinessFlag: String, Sendable, Codable, CaseIterable {
    case elevatedRestingHR, lowHRV, shortSleep, lowSpO2
}

public struct Readiness: Sendable, Codable, Equatable {
    public var score: Int            // 0...100
    public var flags: [ReadinessFlag]

    public init(score: Int, flags: [ReadinessFlag]) {
        self.score = score
        self.flags = flags
    }

    /// One or two words for the watch ring.
    public var shortHeadline: String {
        switch score {
        case 85...: "พร้อม"
        case 50..<85: "เบาๆ"
        default: "ควรพัก"
        }
    }

    /// Neutral readiness used for planning when there is no health data at all:
    /// moderate, so the plan is neither reckless nor needlessly cautious.
    public static let unknown = Readiness(score: 70, flags: [])

    public var headline: String {
        switch score {
        case 85...: "พร้อมออกกำลังกาย"
        case 50..<85: "พร้อมแบบเบาๆ"
        default: "ควรพักวันนี้"
        }
    }
}

public struct ReadinessEngine: Sendable {
    // Starting values to tune with real testing; these are not medical thresholds.
    public var restingHRDelta: Double = 7      // bpm above baseline
    public var hrvDropRatio: Double = 0.8      // below 80% of baseline
    public var minSleepHours: Double = 6
    public var minSpO2: Double = 0.94

    public init() {}

    public func evaluate(today: DailyMetrics, baseline: Baseline) -> Readiness {
        let checks = explain(today: today, baseline: baseline)
        let flags = checks.filter { $0.status == .flagged }.map(\.flag)
        let penalty = checks.filter { $0.status == .flagged }.reduce(0) { $0 + $1.penalty }
        return Readiness(score: max(0, 100 - penalty), flags: flags)
    }

    /// One row per rule, so the UI can show "your value today vs. the rule" and
    /// answer "why did I get this score?" with the exact same logic as `evaluate`.
    public func explain(today: DailyMetrics, baseline: Baseline) -> [ReadinessCheck] {
        var out: [ReadinessCheck] = []

        out.append(check(.elevatedRestingHR, penalty: 25, value: today.restingHR, baseline: baseline.restingHR) {
            guard let base = baseline.restingHR else { return nil }
            return $0 > base + restingHRDelta
        })
        out.append(check(.lowHRV, penalty: 25, value: today.hrv, baseline: baseline.hrv) {
            guard let base = baseline.hrv else { return nil }
            return $0 < base * hrvDropRatio
        })
        out.append(check(.shortSleep, penalty: 15, value: today.sleepHours, baseline: nil) {
            $0 < minSleepHours
        })
        out.append(check(.lowSpO2, penalty: 15, value: today.spo2, baseline: nil) {
            $0 < minSpO2
        })
        return out
    }

    private func check(_ flag: ReadinessFlag, penalty: Int, value: Double?, baseline: Double?,
                       isFlagged: (Double) -> Bool?) -> ReadinessCheck {
        let status: ReadinessCheck.Status
        if let value, let flagged = isFlagged(value) {
            status = flagged ? .flagged : .ok
        } else {
            status = .noData
        }
        return ReadinessCheck(flag: flag, penalty: penalty, value: value, baseline: baseline, status: status)
    }
}

public struct ReadinessCheck: Sendable, Equatable, Identifiable {
    public enum Status: Sendable, Equatable { case ok, flagged, noData }

    public var flag: ReadinessFlag
    public var penalty: Int
    public var value: Double?
    public var baseline: Double?
    public var status: Status

    public var id: ReadinessFlag { flag }
}

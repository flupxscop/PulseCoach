import Foundation
import Testing
@testable import PulseCore

private func metrics(rhr: Double? = 57, hrv: Double? = 51, spo2: Double? = 0.97,
                     sleep: Double? = 7.4, steps: Double = 8000) -> DailyMetrics {
    DailyMetrics(date: .now, restingHR: rhr, hrv: hrv, spo2: spo2, sleepHours: sleep, steps: steps)
}

@Test func elevatedRestingHRIsFlagged() {
    let base = Baseline(restingHR: 55, hrv: 60)
    let r = ReadinessEngine().evaluate(today: metrics(rhr: 66, hrv: 58, sleep: 7.5), baseline: base)
    #expect(r.flags == [.elevatedRestingHR])
    #expect(r.score == 75)
}

@Test func missingDataIsNotPenalised() {
    let today = DailyMetrics(date: .now, restingHR: nil, hrv: nil, spo2: nil, sleepHours: nil, steps: 0)
    let r = ReadinessEngine().evaluate(today: today, baseline: Baseline())
    #expect(r.score == 100 && r.flags.isEmpty)
}

/// DEF-01: "no data" must be detectable so the UI never shows a perfect 100.
@Test func detectsMissingReadinessData() {
    #expect(!DailyMetrics(date: .now, restingHR: nil, hrv: nil, spo2: nil, sleepHours: nil, steps: 4000).hasReadinessData)
    #expect(metrics().hasReadinessData)
    #expect(DailyMetrics(date: .now, restingHR: nil, hrv: nil, spo2: nil, sleepHours: 6, steps: 0).hasReadinessData)
}

@Test func allFlagsStackAndClampAtZero() {
    var engine = ReadinessEngine()
    engine.restingHRDelta = 0
    let base = Baseline(restingHR: 50, hrv: 100)
    let r = engine.evaluate(today: metrics(rhr: 70, hrv: 40, spo2: 0.90, sleep: 4), baseline: base)
    #expect(Set(r.flags) == Set(ReadinessFlag.allCases))
    #expect(r.score == 20)
}

@Test func thresholdsAreStrict() {
    // Exactly at the threshold is not flagged.
    let base = Baseline(restingHR: 55, hrv: 50)
    let r = ReadinessEngine().evaluate(today: metrics(rhr: 62, hrv: 40, spo2: 0.94, sleep: 6), baseline: base)
    #expect(r.flags.isEmpty)
}

@Test func baselineUsesMedianAndIgnoresGaps() {
    let history = [
        metrics(rhr: 50, hrv: nil), metrics(rhr: 52, hrv: 40),
        metrics(rhr: 90, hrv: 60), metrics(rhr: nil, hrv: 50)
    ]
    let base = Baseline.from(history: history)
    #expect(base.restingHR == 52)
    #expect(base.hrv == 50)
}

@Test func emptyHistoryGivesEmptyBaseline() {
    #expect(Baseline.from(history: []) == Baseline())
}

@Test func explainMatchesEvaluate() {
    let engine = ReadinessEngine()
    let base = Baseline(restingHR: 57, hrv: 51)
    let today = metrics(rhr: 58, hrv: 54, spo2: nil, sleep: 5.5)
    let checks = engine.explain(today: today, baseline: base)
    let r = engine.evaluate(today: today, baseline: base)
    #expect(checks.map(\.flag) == ReadinessFlag.allCases)
    #expect(checks.first { $0.flag == .lowSpO2 }?.status == .noData)
    #expect(checks.first { $0.flag == .shortSleep }?.status == .flagged)
    #expect(r.flags == [.shortSleep] && r.score == 85)
}

@Test func checkFormattingIsHumanReadable() {
    let checks = ReadinessEngine().explain(today: metrics(rhr: 58, hrv: 54, spo2: 0.97, sleep: 7.4),
                                           baseline: Baseline(restingHR: 57, hrv: 51))
    let byFlag = Dictionary(uniqueKeysWithValues: checks.map { ($0.flag, $0) })
    #expect(byFlag[.shortSleep]?.formattedValue == "7 ชม. 24 น.")
    #expect(byFlag[.lowSpO2]?.formattedValue == "97%")
    #expect(byFlag[.elevatedRestingHR]?.statusText == "ปกติ")
    #expect(byFlag[.lowHRV]?.statusText == "↑ ดีขึ้น")
}

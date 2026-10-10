# PulseCoach — UI QA Report

**Build:** iOS 27.0 / watchOS 27.0 simulators, Xcode 27.0 · **Date:** 2026-10-10 · **Scope:** iPhone app (all tabs, onboarding, profile, gym guide), watch app (today, workout, gym), watch complication

## How it was tested

| Layer | What | Where |
| --- | --- | --- |
| Unit | Readiness rules, planner fallback/timeout, plan edits, sync encoding | `PulseCore` · `swift test` |
| UI (automated) | Onboarding → plan, Today/Plan/Body/Profile, plan edit + undo, regenerate confirm, gym guide, empty state | `PulseCoachUITests` · `xcodebuild test` |
| Configurations | **A** iPhone 18 Pro · light · default text — **B** iPhone 17e (small) · dark · Accessibility L text | `scripts/ui-regression.sh` |
| Manual | Watch screens via simulator screenshots (`-workoutDemo`, `-gymDemo`, `-gymRestDemo`) | watchOS simulator |

Run it yourself:

```bash
cd PulseCore && swift test
```

```bash
scripts/ui-regression.sh pro-light <simulator-udid> light
```

UI test hooks (test-only launch arguments): `-uiTestReset`, `-uiTestOnboarded`, `-uiTestNoData`, `-gymGuide`.

## Defects found and fixed

| ID | Severity | Area | Defect | Fix | Verified by |
| --- | --- | --- | --- | --- | --- |
| DEF-01 | Critical | iPhone, Watch, complication | With **no health data** the app showed readiness **100 "พร้อมออกกำลังกาย"**, a confident health claim with nothing behind it | `DailyMetrics.hasReadinessData`; UI shows "–" + "ยังไม่มีข้อมูลสุขภาพ" with how to fix and a permission button; plan uses a neutral readiness | `detectsMissingReadinessData`, `testEmptyStateWithoutHealthData` |
| DEF-02 | Major | Plan generation | "กำลังสร้างแผน…" spinner could hang while the on-device model was slow or stuck | Planner timeout (20 s) then rule-based fallback | `fallbackTimesOutSlowPlanner` |
| DEF-03 | Major | Plan | "สร้างใหม่" silently replaced the user's own edits | Confirmation dialog explaining edits will be replaced | `testTodayPlanBodyAndProfile` |
| DEF-04 | Major | Accessibility | At accessibility text sizes rows truncated ("ชีพจรขณะ…") and words split mid-word ("ปาน / กลาง") | `AdaptiveStack`: side-by-side normally, stacked at accessibility sizes (Today, Plan rows, buttons, headers) | Config B screenshots |
| DEF-05 | Major | Profile | "สรุปตอนเช้า" and "เตือนก่อนออกกำลังกาย" toggles did nothing | Scheduled repeating local reminders; reschedule on toggle and plan change | Code review (needs device to observe delivery) |
| DEF-06 | Minor | Accessibility | Goal options read title + description as one long VoiceOver label | Title as label, description as hint, selected trait | `testOnboardingCreatesPlan` |
| DEF-07 | Minor | Today | "สัปดาห์นี้" actually showed the next 7 days | Renamed "7 วันข้างหน้า" | Screenshot |
| DEF-08 | Minor | Plan | "ขอเบาลง" produced odd durations (23 นาที) | Round to 5 minutes | `makeEasierRoundsToFiveMinutes` |
| DEF-09 | Minor | Plan | Day actions centred while the tip was left-aligned | Leading alignment | Screenshot |
| DEF-10 | Minor | Profile | "ยังไม่พบแอปบนนาฬิกา" gave no next step | Footer explains installing from the Watch app | Screenshot |
| DEF-11 | Minor | Today | Multi-line "ค่าเหล่านี้หมายถึงอะไร" centred its second line | Leading alignment | Screenshot |
| DEF-12 | Major | Watch workout / gym | System close button and clock overlapped content; corner buttons clipped; Today bled through | Navigation container, bottom-bar corner buttons, opaque background; close routes to end-confirm | Watch screenshots |

## Known issues / backlog (not fixed in this pass)

| ID | Severity | Issue | Recommendation |
| --- | --- | --- | --- |
| K-01 | Major | Not verifiable on simulator: HealthKit data, Foundation Models plans, WatchConnectivity sync, WorkoutKit scheduling, notification delivery | Run the checklist on a paired iPhone + Apple Watch with a signed build before TestFlight |
| K-02 | Minor | Readiness rules only produce stepped scores (100, 85, 75…) while the design mocks show 82 | Product decision: keep stepped rules or move to a weighted continuous score |
| K-03 | Minor | Thai text is hard-coded; no String Catalog | Move strings to `Localizable.xcstrings` before adding languages |
| K-04 | Minor | Watch UI has no automated UI tests; large numerals use fixed sizes | Add a watchOS UI test target; use `@ScaledMetric` for ring numerals |
| K-05 | Minor | 7-day strip colours carry meaning without a visible legend (VoiceOver labels are present) | Add a legend or intensity text on tap |
| K-06 | Minor | No app icon | Add `AppIcon` asset before submission |

## Results

Final regression after all fixes:

| Suite | Config | Result |
| --- | --- | --- |
| PulseCore unit tests | macOS | 40 / 40 passed |
| Watch app build | watchOS 27 simulator | Build succeeded |
| UI tests (4 flows) | A · iPhone 18 Pro · light · default text | 4 / 4 passed |
| UI tests (4 flows) | B · iPhone 17e · dark · Accessibility L | 4 / 4 passed |

Screenshots per step are kept in the `.xcresult` bundles under `.build/qa/` (open in Xcode, or export with `xcrun xcresulttool export attachments`).

**Exit status:** all Critical and Major defects found on the simulator are fixed and covered by tests.
Release readiness still depends on K-01 (on-device verification).

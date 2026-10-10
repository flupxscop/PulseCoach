# Changelog

All notable changes to this project are documented here.
The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and the project uses [Semantic Versioning](https://semver.org/).

## [0.1.0] - 2026-10-10

First preview build. Runs end to end on the iOS 27 and watchOS 27 simulators; on-device verification is still pending.

### Added
- **Readiness score** from resting heart rate, HRV, sleep and blood oxygen, compared against the user's own 28-day baseline.
- **7-day training plan** generated on-device with Foundation Models, with a rule-based fallback when the model is unavailable or slow.
- **Safety rules** applied to every plan: easy first day on low readiness, no back-to-back hard days, at least one rest day.
- **Plan editing** on iPhone: move a day to tomorrow or make it easier, with undo.
- **iPhone app**: onboarding with goal setup, Today, Plan, Body and Profile, Liquid Glass tab bar, reminders.
- **Apple Watch app**: readiness ring, live workouts with heart rate and zones, end-of-workout confirmation.
- **Gym mode**: exercise guide on iPhone; guided sets, Digital Crown rep counting and rest timer on the watch.
- **Readiness complication** for the watch face.
- **WorkoutKit** scheduling into the Workout app and **WatchConnectivity** sync between iPhone and watch.
- **Demo mode** with sample data for the simulator and App Review.
- Unit tests (Swift Testing) and end-to-end UI tests (XCUITest) with a regression runner.

### Known issues
- HealthKit data, Foundation Models plans, phone–watch sync and notification delivery are not yet verified on physical devices.
- No app icon yet.
- See [docs/QA-Report.md](docs/QA-Report.md) for the full list.

[0.1.0]: https://github.com/flupxscop/PulseCoach/releases/tag/v0.1.0

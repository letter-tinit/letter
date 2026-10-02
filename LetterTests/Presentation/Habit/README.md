# Habit Presentation unit tests

These tests exercise the four Habit view models using doubles of their Domain
use-case protocols. Doubles and snapshots live in `LetterTests`; no database,
notification service, app-side fixture hook, or UI automation is required.

| Owner | Verified contracts |
| --- | --- |
| CreateHabitViewModel | Invalid input prevents submission; create/edit draft mapping; trimming and date normalization; Count/Todo; edit initialization; frequency synchronization; reminder ordering, deletion, and identity; save failure/retry |
| HabitViewModel | Snapshot loading and fetch recovery; selected date and normalized queries; forced item refresh; progress cache reuse/invalidation; progress-to-view mapping; entry result handling and action arguments; notification delegation with latest snapshots |
| HabitDetailViewModel | Snapshot display mapping; missing habit; load/delete/complete failures and retries; completion arguments; enabled reminder ordering; Todo and empty-value localization |
| HabitStatisticsViewModel | Reload and failure recovery; persisted compact preference and failed writes; scope/calendar forwarding; aggregate input forwarding; availability cache invalidation and visibility |

The existing `HabitStatisticDateLayoutTests` remain in their original file.
Domain calculation correctness is tested in Domain tests; these tests verify
Presentation state and the contracts at the use-case boundary.

Run the four view-model suites independently using the shared `Letter` scheme:

```sh
xcodebuild -project Letter.xcodeproj -scheme Letter \
  -destination 'platform=iOS Simulator,name=iPhone 12 mini' \
  -only-testing:LetterTests/CreateHabitViewModelTests \
  -only-testing:LetterTests/HabitViewModelTests \
  -only-testing:LetterTests/HabitDetailViewModelTests \
  -only-testing:LetterTests/HabitStatisticsViewModelTests test
```

## Boundaries

This suite does not replace the Habit UI tests for navigation, keyboard behavior,
sheet/confirmation interaction, layout, accessibility, or app relaunch persistence.
It does not claim complete line or branch coverage. Midnight rollover, changes to
system time zone, actual haptic delivery, and notification delivery are not
simulated. Tests use fixed historical dates for date-dependent inputs and compare
normalization against the calendar supplied by `CalendarPreferences`.

Home item-load failure recovery currently exercises an explicit forced refresh.
Unforced retry after a failed query and an error followed by a missing detail
record remain audit gaps; their desired UI behavior needs separate verification.

## Validation

October 1, 2026: all 35 new view-model cases passed as part of the complete
230-test `LetterTests` run on iPhone 12 mini / iOS 26.5 Simulator. The app built
successfully; there were zero failures, skips, or runtime warnings. Together with
the four existing date-layout cases, Habit has 39 focused Presentation unit tests.
No UI tests were executed for this change.

Local result bundle: `/tmp/HabitPresentationAllUnitTests.xcresult`.

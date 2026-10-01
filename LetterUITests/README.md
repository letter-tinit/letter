# Habit UI tests

Select the shared `Letter` scheme for everyday development: Command-U runs only
`LetterTests` (unit tests). To run UI tests, select the shared `LetterUITests`
scheme and an iPhone simulator, then press Command-U. That scheme runs only
`LetterUITests`. Use the Test navigator to run individual tests in either scheme.
Xcode installs and launches the app itself.

From the repository root:

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild \
  -project Letter.xcodeproj -scheme LetterUITests \
  -destination 'platform=iOS Simulator,name=iPhone 12 mini' \
  -only-testing:LetterUITests -parallel-testing-enabled NO test
```

## Coverage

Test setup lives in `LetterUITests`: prerequisites are created through the app's
forms, calendar pickers, and tracking controls. There is no app-side fixture loader
or repository seeding. The existing Debug session flag selects a temporary database;
it does not bypass any Habit workflow.

| Test class | User-facing workflows |
| --- | --- |
| `HabitHomeUITests` | Empty state, tab return, past-day selection, independent daily progress, detail streak values, end-date visibility |
| `HabitFormUITests` | Creation/edit/cancel, name/count/unit validation, goal-type switching, symbol/color, reminder add/delete/time editing, saved goal/schedule edits |
| `HabitScheduleUITests` | Daily/weekday/weekend/custom schedules, saved weekday selections, start/end date selection/save/reset/cancel, date limits and relaunch |
| `HabitEntryUITests` | Todo/count tracking, remaining goal, keypad clear/backspace/zero/dismiss, above-goal counts, skip/reset, row sorting, week navigation, disabled future progress and allowed future skip/reset |
| `HabitLifecycleUITests` | Delete/complete confirmations and cancellation, history retention/removal, completed date, resuming tracking, deletion after relaunch |
| `HabitStatisticsUITests` | Empty/no-record states, both modes, all scopes, summary values, past-period navigation and boundaries, compact toggle and saved preference |
| `HabitAccessibilityUITests` | Large-text control reachability and Vietnamese creation/detail smoke checks |

## Working process

The original 32 test methods retain their names and owning classes. Additional
coverage is added alongside them; existing tests are not removed to make a run pass.

1. The agent writes or updates test code and checks compilation.
2. The developer runs the `LetterUITests` scheme in Xcode.
3. The developer shares any failures and their diagnostics.
4. The agent investigates whether the test or feature is wrong and fixes the
   confirmed cause; the developer runs the tests again.

The task is complete only after the developer confirms every test passes. Agents
must not launch UI test runs as part of this workflow unless requested.

- Form validation: empty/whitespace names, positive count targets, nonempty units,
  and custom schedules with at least one selected day.
- Creation, cancellation, count/Todo goals, description, editing, style selection,
  frequency presets, reminder addition/removal, and date picker set/reset/cancel.
- Todo completion, accumulating count progress, completing the remaining goal,
  keypad clear/backspace/zero, skip/reset, and independent entries across habits.
- Week navigation, return to today, future entry restrictions, dates before the
  habit starts, and persistence across termination and relaunch.
- Delete/complete confirmation and cancellation, retained completion history,
  removed deletion history, and resuming a completed habit by resetting its entry.
- Empty/populated statistics, overview/by-habit modes, week/month/year scopes,
  compact view, and period navigation boundaries.

Each test gets a UUID-based SwiftData store in the app's temporary directory.
Relaunches within that test reuse its store; a new test receives a new store.
`LETTER_UI_TEST_SESSION` is honored only by Debug builds. Other storage adapters
use their existing in-memory implementations. Tests pass English preferences
through the launch argument domain, without changing saved language preferences.

These are interface/integration tests against real Habit use cases and persistence.
They do not assert delivery timing of operating-system notifications, notification
permission denial, injected storage failures, or every calendar/streak edge case;
the existing deterministic unit tests cover business policy boundaries. Failed UI
tests attach a screenshot and the accessibility tree to the Xcode result bundle.

The goal/schedule edit regression exposed a persistence defect: the adapter omitted
frequency, weekdays, goal type, count, and unit when applying edits. Those fields
now persist, and the Domain form use case recalculates streaks using the edited
schedule and goal. Existing progress records are preserved. Repository and Domain
unit regressions cover both boundaries; `testEditingGoalAndRepeatPersistsChanges`
checks the end-to-end editing workflow with ordinary assertions.

The suite covers interactive workflows, not every rendering permutation. Manual
checks remain appropriate for visual appearance, VoiceOver reading order, dark
mode, animation quality, and physical-device notification delivery. The large-text
and language tests are smoke checks, not a full accessibility/localization audit.

## Validation

Current expansion (October 1, 2026): 50 UI tests, including all 32 original
methods under their original classes. The app and UI test target passed
`build-for-testing`; this compiles without executing UI tests. Full validation of
the current suite is pending the developer's run and confirmation. Earlier run
results below apply to the earlier 32-test suite, not the expanded suite.

At the developer's explicit request on October 1, all 18 additional UI tests
passed on iPhone 12 mini / iOS 26.5 Simulator across focused runs. Five cases
completed before an XCUITest animation-idle stall; after restarting the simulator,
the remaining 13 passed with no runtime warnings. All 195 unit tests also passed,
including three new regressions for edited persistence and streak recalculation.
The original 32 UI tests were not rerun in this verification. Full-suite
confirmation remains pending. No original test methods were deleted or renamed.

Verified on September 30, 2026: 31 UI tests passed on iPhone 17 / iOS 27.0;
the completed-habit reset UI test passed on iPhone 12 mini / iOS 26.5.
All 52 selected existing Habit unit tests passed on iOS 26.5. The app and both
test targets built successfully, and staged/unstaged diff checks passed.

After the keyboard and navigation fixes, all 32 UI tests and seven
`ImpHabitRepositoryTests` passed together on iPhone 12 mini / iOS 26.5 Simulator.
The result bundle reported zero runtime warnings. The app and both test targets
built successfully, and `git diff --check` passed.

The form helpers dismiss the keyboard using its accessibility identifier and
wait for the controls to disappear before scrolling within the form's viewport.
Scrolling can move in either direction, including on smaller physical phones.
Statistics mode selection waits for menu choices before tapping them. Shared
keyboard controls use a safe-area bar to avoid native keyboard-toolbar frame
warnings on iOS 26.

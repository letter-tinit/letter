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

Known existing limitation: the edit form displays editable repeat/goal controls,
but `ImpHabitRepository.apply(_:to:)` retains the original frequency, target
weekdays, goal type, target count, and unit. The edit workflow tests exercise the
fields currently persisted (name, description, style, duration, and reminders).
Changing that behavior is outside this testing change.

## Validation

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

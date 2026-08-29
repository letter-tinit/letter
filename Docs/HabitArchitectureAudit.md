# Habit Architecture Audit

Updated: 2026-08-29

## Executive Summary

The Habit feature is not yet fully Clean Architecture. Its original structure
combined presentation state, business decisions, persistence transactions,
notifications, profile settings, and feedback inside `HabitViewModel`.
Splitting that type into extensions or moving its methods to similarly coupled
files would not fix the dependency problem.

This change establishes the first complete inward-facing boundary: the Habit
home query. SwiftData records are mapped to immutable `HabitSnapshot` values in
Data, application code coordinates the query, domain policy filters and sorts
plain values, and Presentation receives `HabitListItem` values.

## Current Dependency Map

```text
HabitScreen
  -> HabitViewModel
     -> HabitHomeQuerying (Application port)
        -> HabitHomeQuery (Application use case)
           -> HabitSnapshotReading (Application port)
              <- SwiftDataHabitRepository (Data adapter)
           -> HabitListPolicy (Domain)
              -> HabitSnapshot / HabitListItem (Domain values)

Legacy paths still present:
HabitViewModel -> HabitRepository -> SwiftData @Model objects
HabitViewModel -> notification scheduler / haptics / AppCalendar global
Domain policies -> Habit and HabitEntry SwiftData @Model objects
```

## Findings

### Critical: persistence objects leak inward

`Habit`, `HabitEntry`, `HabitReminder`, and `UserProfile` are SwiftData models
located under `Domain`. `HabitRepository` returns those live records. This
makes Presentation and purported Domain policies dependent on object-context
lifetime and is the architectural cause behind detached-fault crashes.

Status: migration started. The Home list no longer receives persistence
objects. The remaining CRUD, statistics, streak, and entry paths still do.

### High: `HabitViewModel` owns unrelated responsibilities

The type still owns:

- Home date and list state.
- Profile loading and editing.
- Habit CRUD and version-chain rules.
- Entry mutation coordination.
- Streak recalculation.
- Reminder replacement and notification scheduling.
- Persistence save/recovery and cache invalidation.

These responsibilities have different reasons to change. File extensions make
them easier to navigate but do not reduce coupling.

Status: Home reads moved behind an application boundary. The type remains a
legacy facade while commands are migrated use case by use case.

### High: extracted policies still mutate SwiftData models

`HabitEntryMutationPolicy`, `HabitStreakCalculator`, and
`HabitStatisticsCalculator` accept live persistence models. Although some are
deterministic, they are not framework-independent domain policies and cannot be
tested without constructing infrastructure-shaped objects.

Status: unresolved. Convert inputs to snapshots/value objects before moving
their orchestration into application use cases.

### Medium: transaction ownership is ambiguous

Mutations, `save()`, rollback/refetch behavior, streak updates, and notification
effects are coordinated in Presentation. A failed save can therefore require a
view model to reconstruct persistence state and external effects.

Status: unresolved. Application command use cases should own each transaction
and return an explicit result such as `updated`, `unchanged`, `notScheduled`,
or `persistenceFailed`.

### Medium: time and calendar dependencies are partly global

Business paths use `Date()` and `AppCalendar.current` directly. This hides
inputs and makes edge cases around midnight, time zones, and week boundaries
harder to reproduce.

Status: improved for the Home domain policy. It receives the selected date,
today, and calendar explicitly. Other paths remain legacy.

### Medium: automated architecture safety net is missing

There is no focused Habit domain/application test target visible in the
project. Builds detect integration errors but not scheduling, sorting, skip,
reset, versioning, or streak regressions.

Status: unresolved. Add a test target before migrating high-risk commands.

## Target Ownership

| Concern | Intended owner |
| --- | --- |
| Schedule, completion, streak, and version rules | Domain policies over values |
| Load Home, update progress, skip, reset, CRUD | Application use cases |
| SwiftData fetch/mapping/save | Data adapters |
| User notifications | Infrastructure adapter behind a port |
| Localized text, haptics, sound, navigation | Presentation |
| Concrete construction | `AppContainer` |

## Migration Order

1. **Home query — completed in this change.** Keep the view on immutable row
   values and resolve a live Habit only at the synchronous legacy command edge.
2. **Entry commands.** Replace model-mutating policy results with pure domain
   decisions and application use cases for progress, skip, and reset.
3. **Habit CRUD and versioning.** Introduce command DTOs and make a use case own
   save, rollback, refetch, and notification coordination.
4. **Statistics and streaks.** Reuse domain snapshots, remove SwiftData inputs,
   and add deterministic tests.
5. **Profile extraction.** Move profile state out of `HabitViewModel`; it is not
   a Habit Home responsibility.
6. **Persistence model relocation.** Rename SwiftData classes as records and
   move them under Data once all callers depend on domain values and ports.

## Definition of Done for the Habit Migration

- No file under Domain or Application imports or exposes SwiftData.
- Habit views and observable view models do not retain SwiftData records.
- Each user command enters through one application use case.
- Business policies accept explicit value inputs, including date/calendar.
- Transactions and external side effects have one application owner.
- Domain and application tests run without a model container or simulator.
- `HabitViewModel` is removed or reduced to cohesive presentation state below
  the repository's architecture-review threshold.

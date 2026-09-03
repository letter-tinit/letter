# Letter Engineering Rules

These instructions apply to the entire repository. Every AI agent must read and
follow them before changing code.

## Architectural Goal

Letter follows Clean Architecture. Dependencies point inward:

```text
Presentation -> Domain
Data/Infrastructure -> Domain ports
Composition Root -> all concrete implementations
```

Moving the same logic into another file or extension is not an architectural
refactor. A refactor is complete only when ownership, dependencies, and test
boundaries improve.

## Layer Responsibilities

### Domain

- Contains business entities, value objects, domain errors, deterministic
  business policies, use cases, and repository/service ports.
- Must not import SwiftUI, Observation, SwiftData, UserNotifications, UIKit, or
  other infrastructure frameworks.
- May use Foundation value types such as `Date`, `UUID`, and `Calendar` when
  passed explicitly.
- Domain policies must not save data, schedule notifications, log, trigger
  haptics, or read global application state.
- Business decisions belong here, not in views, view models, repositories, or
  framework callbacks.
- A use case coordinates domain policies and repository/service ports for one
  cohesive goal.
- Use cases must not know concrete repository, database, or system-service
  types.
- Returns explicit output/result types. Do not encode meaningful failures as a
  bare `Bool` when the caller needs to distinguish causes.

### Presentation

- Contains SwiftUI views, observable view models, routers, and presentation
  models.
- Form state, text parsing, UI input validation, picker/segment enums, and any
  model that exists only to construct view input belong beside the owning view
  in Presentation. Do not place these types in Domain merely because their
  names contain `Model`, `Input`, or `Validation`.
- View models own UI state and translate use-case output into presentation
  state. They do not implement business rules or persistence transactions.
- Views receive immutable presentation models where practical. Do not retain
  live persistence objects in lazy or asynchronous UI work.
- Haptics, localized strings, animation, navigation, and UI-only flags remain
  in this layer.
- Use the shared `Styleguide` typography entry point (`customFont`) for visible
  text and glyphs. It preserves Dynamic Type while applying Letter's rounded
  type design consistently; do not add ad-hoc system fonts in feature views.
- Keep feature screens as coordinators. Place reusable SwiftUI components in
  that feature's `View/` directory rather than duplicating layout in screens.

### Data and Infrastructure

- Contains SwiftData models/adapters, repository implementations, backup
  stores, notification schedulers, and other framework integrations.
- SwiftData persistence records belong under `Data/Persistence`; map them to
  framework-independent Domain models at the repository boundary.
- Implements ports declared by inner layers.
- Maps between persistence records and domain models at the boundary.
  Infrastructure types must not leak inward.

### Composition Root

- `AppContainer` creates concrete implementations and injects them through
  protocols/use-case interfaces.
- The composition root belongs to the executable app target. Do not move
  `AppContainer` into a shared package because it must know Data, Domain, and
  Presentation concrete types.
- Do not instantiate concrete repositories or infrastructure services inside
  views, view models, domain policies, or use cases.

### Utility

- Contains small framework-independent helpers and extensions reused by more
  than one package, such as formatting, logging, and calendar helpers.
- A helper is not a business entity or policy. Business decisions that use a
  calendar still receive `Calendar` explicitly in Domain rather than reading a
  Utility global.
- Letter intentionally has no generic `Core` package. Do not recreate one as a
  dumping ground or add `import Core`. Introduce a narrowly named package only
  when it has a cohesive responsibility and a real reuse boundary.

## Clean Code Rules

- Give every type one primary reason to change.
- Prefer cohesive use cases and policies over manager/service god objects.
- Keep functions focused. A function approaching 30 lines or mixing decisions
  with I/O must be decomposed or justified.
- Treat a type approaching 300 lines as an architecture review trigger, not as
  a request to split extensions into files.
- Remove confirmed dead code instead of preserving speculative APIs.
- Avoid duplicated save/refetch/recovery workflows; centralize them in a use
  case or transaction boundary.
- Inject time/calendar behavior into business rules. Do not hide `Date()`,
  `Calendar.current`, or application singletons inside domain decisions.
- Do not access SwiftData models after deletion, across detached contexts, or
  from escaping callbacks. Snapshot or map at the boundary.
- Preserve unrelated user changes in a dirty worktree.

## Required Agent Workflow

Before a structural change:

1. Identify the current layer, callers, side effects, and dependency direction.
2. State the intended owner of the behavior and why.
3. Prefer one complete vertical slice over many partially extracted files.
4. Keep behavior stable unless the user explicitly requests a behavior change.
5. Classify a type by what it does and who consumes it, never by filename
   suffixes such as `Model`, `Manager`, `Input`, or `Service`.

Before completion:

1. Search for dead call sites and obsolete APIs.
2. Run `git diff --check`.
3. Build the affected target and run relevant tests when a test target exists.
4. Report what moved between layers, not only which files changed.
5. Report remaining known violations; do not claim Clean Architecture while
   infrastructure still leaks into inner layers.

## Testing Rules

- The project currently has no test target. Do not create a new test target or
  `LetterTests` directory unless the user explicitly requests that workflow.
- Keep domain policies and use cases deterministic and independently testable so
  focused tests can be introduced later without UI or infrastructure frameworks.
- A successful app build is required for every behavior or structural change.

## Current Legacy Boundaries

The following are known migration debt and must not be expanded:

- `HabitViewModel` still coordinates repository and notification side effects.
- Some profile and backup behavior shares the Habit persistence context.
- The project currently lacks focused automated tests for Habit policies and
  use cases.

When touching these areas, move one dependency inward behind a port or map it
outward into Data. If that cannot be done safely in the requested scope, record
the remaining violation in the handoff.

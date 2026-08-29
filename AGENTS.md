# Letter Engineering Rules

These instructions apply to the entire repository. Every AI agent must read and
follow them before changing code.

## Architectural Goal

Letter follows Clean Architecture. Dependencies point inward:

```text
Presentation -> Application -> Domain
Data/Infrastructure -> Application/Domain ports
Composition Root -> all concrete implementations
```

Moving the same logic into another file or extension is not an architectural
refactor. A refactor is complete only when ownership, dependencies, and test
boundaries improve.

## Layer Responsibilities

### Domain

- Contains business entities, value objects, domain errors, and deterministic
  business policies.
- Must not import SwiftUI, Observation, SwiftData, UserNotifications, UIKit, or
  other infrastructure frameworks.
- May use Foundation value types such as `Date`, `UUID`, and `Calendar` when
  passed explicitly.
- Domain policies must not save data, schedule notifications, log, trigger
  haptics, or read global application state.
- Business decisions belong here, not in views, view models, repositories, or
  framework callbacks.

### Application

- Contains use cases and ports that describe user/application actions.
- A use case coordinates domain policies and repository/service ports for one
  cohesive goal.
- Must not import SwiftUI, SwiftData, UserNotifications, or UIKit.
- Must not know concrete repository, database, or system-service types.
- Returns explicit output/result types. Do not encode meaningful failures as a
  bare `Bool` when the caller needs to distinguish causes.

### Presentation

- Contains SwiftUI views, observable view models, routers, and presentation
  models.
- View models own UI state and translate use-case output into presentation
  state. They do not implement business rules or persistence transactions.
- Views receive immutable presentation models where practical. Do not retain
  live persistence objects in lazy or asynchronous UI work.
- Haptics, localized strings, animation, navigation, and UI-only flags remain
  in this layer.

### Data and Infrastructure

- Contains SwiftData models/adapters, repository implementations, backup
  stores, notification schedulers, and other framework integrations.
- Implements ports declared by inner layers.
- Maps between persistence records and domain/application models at the
  boundary. Infrastructure types must not leak inward.

### Composition Root

- `AppContainer` creates concrete implementations and injects them through
  protocols/use-case interfaces.
- Do not instantiate concrete repositories or infrastructure services inside
  views, view models, domain policies, or use cases.

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

Before completion:

1. Search for dead call sites and obsolete APIs.
2. Run `git diff --check`.
3. Build the affected target and run relevant tests.
4. Report what moved between layers, not only which files changed.
5. Report remaining known violations; do not claim Clean Architecture while
   infrastructure still leaks into inner layers.

## Testing Rules

- Add or update tests for extracted domain policies and application use cases.
- Domain tests must run without SwiftUI, SwiftData stores, notifications, or a
  simulator where the project test setup permits it.
- Use fakes for repository and service ports in use-case tests.
- A successful app build is required but is not a replacement for business-rule
  tests.

## Current Legacy Boundaries

The following are known migration debt and must not be expanded:

- Habit domain models currently use SwiftData `@Model` directly.
- `HabitViewModel` still coordinates repository and notification side effects.
- Some profile and backup behavior shares the Habit persistence context.
- The project currently lacks focused automated tests for Habit policies and
  use cases.

When touching these areas, move one dependency inward behind a port or map it
outward into Data. If that cannot be done safely in the requested scope, record
the remaining violation in the handoff.

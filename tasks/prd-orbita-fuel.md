# PRD: OrbitaFuel — Interplanetary Fuel Calculator

## Introduction

OrbitaFuel is a Phoenix 1.8 / LiveView web application that calculates the fuel required for interplanetary travel. Users define a spacecraft mass and a flight path composed of sequential launch/land steps across Earth, Moon, and Mars. The app returns a real-time recursive fuel breakdown per step and a grand total. No database is required — all state lives in the LiveView socket.

This PRD is written for autonomous AI agent execution. Instructions are precise and unambiguous. Implementation must follow `spec.md` exactly.

---

## Goals

- Implement pure-functional fuel calculation logic using `Stream.unfold`
- Implement embedded schemas for validation (no Repo calls)
- Deliver a single-LiveView UI with real-time reactivity
- Achieve 100% test coverage via ExCoveralls
- Pass `mix precommit` with zero warnings, zero failures

---

## Stack & Version Constraints

| Dependency         | Version              |
|--------------------|----------------------|
| Elixir             | ~> 1.15              |
| Phoenix            | ~> 1.8.1             |
| Phoenix LiveView   | ~> 1.1.0             |
| Tailwind CSS       | via `tailwind` hex   |
| Heroicons          | v2.2.0 (sparse)      |
| ExCoveralls        | ~> 0.18 (`:test`)    |

No Ecto Repo calls. `embedded_schema` is used for changeset validation only.

---

## User Stories

### US-001: Calculator — base_fuel/3
**Description:** As an agent, I need a pure function that computes raw (non-accumulated) fuel for a single step so the recursive chain can be built on top of it.

**Acceptance Criteria:**
- [ ] Create `lib/orbita_fuel/travel/calculator.ex`
- [ ] Define `base_fuel(mass, gravity, :launch)` → `floor(mass * gravity * 0.042 - 33)`
- [ ] Define `base_fuel(mass, gravity, :land)` → `floor(mass * gravity * 0.033 - 42)`
- [ ] Return value is an integer (may be negative for small masses — do NOT clamp)
- [ ] `mix compile --warning-as-errors` passes

---

### US-002: Calculator — fuel_chain/3
**Description:** As an agent, I need a lazy stream that generates the full recursive fuel chain for one step so each intermediate value is available for display.

**Acceptance Criteria:**
- [ ] Define `fuel_chain(mass, gravity, action)` using `Stream.unfold/2`
- [ ] Unfold seed is `mass` (the original spacecraft mass)
- [ ] Each iteration calls `base_fuel(current, gravity, action)` where `current` starts as `mass` then advances to each successive fuel value
- [ ] Iteration stops (returns `nil`) when `base_fuel` result is `<= 0`
- [ ] Returns a materialized list via `Enum.to_list/1`
- [ ] Empty list `[]` for mass so small that `base_fuel` is immediately `<= 0`
- [ ] `mix compile --warning-as-errors` passes

**Reference implementation shape:**
```elixir
Stream.unfold(mass, fn current ->
  fuel = base_fuel(current, gravity, action)
  if fuel <= 0, do: nil, else: {fuel, fuel}
end)
|> Enum.to_list()
```

---

### US-003: Calculator — fuel_for_step/3
**Description:** As an agent, I need a function that returns both the step total and the full chain so the LiveView can display both the subtotal and the breakdown.

**Acceptance Criteria:**
- [ ] Define `fuel_for_step(mass, gravity, action)` returning `{total, chain}`
- [ ] `chain` is the result of `fuel_chain(mass, gravity, action)`
- [ ] `total` is `Enum.sum(chain)`
- [ ] For land Earth 28801 kg: chain = `[9278, 2960, 915, 254, 40]`, total = `13447`
- [ ] `mix compile --warning-as-errors` passes

---

### US-004: Calculator — total_fuel/2
**Description:** As an agent, I need a function that aggregates fuel across all steps so the LiveView can display the grand total and per-step breakdowns.

**Acceptance Criteria:**
- [ ] Define `total_fuel(mass, steps)` where `steps` is a list of `%Step{}` structs
- [ ] For each step, call `fuel_for_step(mass, Step.gravity(step.planet), step.action)`
- [ ] Return `{grand_total, per_step_results}` where `per_step_results` is a list of `{total, chain}` tuples in step order
- [ ] Empty steps list returns `{0, []}`
- [ ] Apollo 11 (mass 28801, 4 steps): grand total = `51898`
- [ ] Mars Mission (mass 14606, 4 steps): grand total = `33388`
- [ ] Passenger Ship (mass 75432, 6 steps): grand total = `212161`
- [ ] `mix compile --warning-as-errors` passes

---

### US-005: Step schema
**Description:** As an agent, I need an embedded schema for a flight step so changesets can validate action and planet values.

**Acceptance Criteria:**
- [ ] Create `lib/orbita_fuel/travel/step.ex`
- [ ] `embedded_schema` with `field :action, Ecto.Enum, values: [:launch, :land]` and `field :planet, Ecto.Enum, values: [:earth, :moon, :mars]`
- [ ] `changeset/2` casts both fields, validates both are required
- [ ] `gravity/1` returns: `:earth` → `9.807`, `:moon` → `1.62`, `:mars` → `3.711`
- [ ] `planet_label/1` returns: `:earth` → `"Earth"`, `:moon` → `"Moon"`, `:mars` → `"Mars"`
- [ ] `action_label/1` returns: `:launch` → `"Launch"`, `:land` → `"Land"`
- [ ] `mix compile --warning-as-errors` passes

---

### US-006: Flight schema
**Description:** As an agent, I need an embedded schema for the full flight so changesets can validate mass and the steps list together.

**Acceptance Criteria:**
- [ ] Create `lib/orbita_fuel/travel/flight.ex`
- [ ] `embedded_schema` with `field :mass, :float` and `embeds_many :steps, Step`
- [ ] `changeset/2` casts `:mass`, validates it is required and `greater_than: 0`
- [ ] `changeset/2` casts and validates embedded steps (propagates step-level errors)
- [ ] `changeset/2` validates `length(steps) >= 1` with `validate_length(:steps, min: 1)`
- [ ] `mix compile --warning-as-errors` passes

---

### US-007: ExCoveralls setup
**Description:** As an agent, I need ExCoveralls configured so 100% coverage can be verified.

**Acceptance Criteria:**
- [ ] Add `{:excoveralls, "~> 0.18", only: :test}` to `deps/0` in `mix.exs`
- [ ] Add `test_coverage: [tool: ExCoveralls]` to `project/0`
- [ ] Add `preferred_cli_env: [coveralls: :test, "coveralls.detail": :test, "coveralls.html": :test]` to `project/0`
- [ ] `mix deps.get` resolves without conflict
- [ ] `mix compile --warning-as-errors` passes

---

### US-008: Calculator tests
**Description:** As an agent, I need exhaustive tests for the Calculator module so all branches are exercised and coverage is 100%.

**Acceptance Criteria:**
- [ ] Create `test/orbita_fuel/travel/calculator_test.exs`
- [ ] `base_fuel` launch — nominal mass returns positive integer
- [ ] `base_fuel` land — nominal mass returns positive integer
- [ ] `base_fuel` result is negative for very small mass (not clamped)
- [ ] `fuel_chain` terminates; result is a list ending before the `<= 0` value
- [ ] `fuel_chain` for mass `1` (or any mass where first fuel is `<= 0`) returns `[]`
- [ ] `fuel_for_step` land Earth 28801 kg — chain equals `[9278, 2960, 915, 254, 40]`
- [ ] `fuel_for_step` land Earth 28801 kg — total equals `13447`
- [ ] `fuel_for_step` launch Earth 28801 kg returns expected value (compute and assert exact)
- [ ] `total_fuel` Apollo 11 (mass 28801, launch Earth → land Moon → launch Moon → land Earth) → `{51898, _}`
- [ ] `total_fuel` Mars Mission (mass 14606, launch Earth → land Mars → launch Mars → land Earth) → `{33388, _}`
- [ ] `total_fuel` Passenger Ship (mass 75432, launch Earth → land Moon → launch Moon → land Mars → launch Mars → land Earth) → `{212161, _}`
- [ ] `total_fuel` with empty steps list → `{0, []}`
- [ ] `mix test` passes with all green

---

### US-009: Step tests
**Description:** As an agent, I need tests for the Step schema covering all valid/invalid combinations and helper functions.

**Acceptance Criteria:**
- [ ] Create `test/orbita_fuel/travel/step_test.exs`
- [ ] Valid changeset `{:launch, :earth}` → `valid? == true`
- [ ] Valid changeset `{:land, :mars}` → `valid? == true`
- [ ] Missing `:action` → changeset error on `:action`
- [ ] Missing `:planet` → changeset error on `:planet`
- [ ] Invalid action value (e.g. `"fly"`) → changeset error on `:action`
- [ ] Invalid planet value (e.g. `"venus"`) → changeset error on `:planet`
- [ ] `gravity(:earth)` → `9.807`
- [ ] `gravity(:moon)` → `1.62`
- [ ] `gravity(:mars)` → `3.711`
- [ ] `planet_label(:earth)` → `"Earth"`
- [ ] `action_label(:launch)` → `"Launch"`
- [ ] `mix test` passes

---

### US-010: Flight tests
**Description:** As an agent, I need tests for the Flight schema covering all validation paths.

**Acceptance Criteria:**
- [ ] Create `test/orbita_fuel/travel/flight_test.exs`
- [ ] Valid flight (mass `28801.0`, one step) → `valid? == true`
- [ ] Valid flight (mass `28801.0`, multiple steps) → `valid? == true`
- [ ] Mass is `nil` → error on `:mass`
- [ ] Mass is `0` → error on `:mass`
- [ ] Mass is `-100` → error on `:mass`
- [ ] Mass is non-numeric string → error on `:mass`
- [ ] Steps is empty list → error on `:steps`
- [ ] Step with invalid action inside flight → error propagated to step level
- [ ] `mix test` passes

---

### US-011: FlightLive — mount and socket assigns
**Description:** As an agent, I need the LiveView mounted at `/` with correct initial socket assigns so the page renders with a default state.

**Acceptance Criteria:**
- [ ] Create `lib/orbita_fuel_web/live/flight_live.ex`
- [ ] Mount at `/` in router (`live "/", FlightLive, :index`)
- [ ] On mount, assigns: `form` (Flight changeset via `to_form/1`), `steps` (one default step with action `:launch`, planet `:earth`), `result` (`nil`), `next_step` (`%{action: :launch, planet: :earth}`)
- [ ] Steps use stable string IDs generated via `:erlang.unique_integer([:positive])`
- [ ] Page renders without crash
- [ ] `mix compile --warning-as-errors` passes

---

### US-012: FlightLive — mass input and validate event
**Description:** As an agent, I need the mass input to debounce and trigger recalculation so users get instant feedback as they type.

**Acceptance Criteria:**
- [ ] `<.form>` element has `id="flight-form"` and `phx-change="validate"`
- [ ] Mass input has `phx-debounce="300"`
- [ ] `handle_event("validate", params, socket)` casts a Flight changeset from params
- [ ] Recalculation runs via `Calculator.total_fuel/2` when changeset is valid
- [ ] `result` assign is set to `%{total: grand_total, per_step: per_step}` on valid input
- [ ] `result` assign is set to `nil` when changeset is invalid
- [ ] Inline error shown below mass input on invalid value
- [ ] `mix compile --warning-as-errors` passes

---

### US-013: FlightLive — step management events
**Description:** As an agent, I need add/remove/update step events so users can build and modify their flight path.

**Acceptance Criteria:**
- [ ] `handle_event("add_step", _params, socket)` appends `next_step` values as a new step with a unique string ID; triggers recalculation
- [ ] `handle_event("remove_step", %{"id" => id}, socket)` removes the step with matching ID; triggers recalculation
- [ ] `handle_event("update_step", %{"id" => id, "field" => field, "value" => value}, socket)` updates `:action` or `:planet` on the matching step; triggers recalculation
- [ ] `handle_event("stage_next_step", params, socket)` updates `next_step` assign only — does NOT add a step, does NOT recalculate
- [ ] Remove button is `disabled` when `length(steps) == 1`
- [ ] `mix compile --warning-as-errors` passes

---

### US-014: FlightLive — preset event
**Description:** As an agent, I need preset buttons that pre-fill both mass and steps so users can quickly load reference scenarios.

**Acceptance Criteria:**
- [ ] `handle_event("load_preset", %{"name" => name}, socket)` replaces `steps` and `mass` with preset values
- [ ] Apollo 11 preset: mass `28801`, steps = launch Earth → land Moon → launch Moon → land Earth
- [ ] Mars Mission preset: mass `14606`, steps = launch Earth → land Mars → launch Mars → land Earth
- [ ] Passenger Ship preset: mass `75432`, steps = launch Earth → land Moon → launch Moon → land Mars → launch Mars → land Earth
- [ ] Loading a preset triggers immediate recalculation
- [ ] `mix compile --warning-as-errors` passes

---

### US-015: FlightLive UI — mission setup panel
**Description:** As an agent, I need the left panel rendered with correct markup so users can interact with mass input, step list, staging row, and presets.

**Acceptance Criteria:**
- [ ] Header: app name `ORBITAFUEL`, `rocket-launch` heroicon, tagline "Interplanetary Fuel Calculator", right-aligned "NASA Challenge" label
- [ ] Background: dark space theme (`#0a0f1e` or Tailwind equivalent)
- [ ] Mass input: label "Spacecraft Mass", `type="number"`, "kg" unit label, inline error on invalid
- [ ] Flight path section: ordered list of step rows; each row has step number badge, action dropdown, planet dropdown, remove `✕` button
- [ ] Remove button `disabled` when only one step
- [ ] Staging row: label "Add next step:", action dropdown, planet dropdown, `[+ Add Step]` button
- [ ] Presets section: three buttons labeled `Apollo 11`, `Mars Mission`, `Passenger Ship`
- [ ] `mix compile --warning-as-errors` passes
- [ ] Verify in browser using dev-browser skill

---

### US-016: FlightLive UI — fuel breakdown panel
**Description:** As an agent, I need the right panel to display the recursive chain and totals so users can see the full calculation breakdown.

**Acceptance Criteria:**
- [ ] Empty state shown when `result` is `nil`: centered icon (`hero-calculator`), text "Enter a mass and build your flight path to see the fuel breakdown."
- [ ] When `result` is set: one card per step showing `Step N · [Action] — [Planet]` header
- [ ] Each card body shows the chain as a vertical stack: first value plain, subsequent values prefixed with `+`, separator line, subtotal labeled "Subtotal: X,XXX kg"
- [ ] Numbers are right-aligned, monospace font
- [ ] Total row below all cards: double rule, label `TOTAL FUEL REQUIRED`, large bold value (e.g. `51,898 kg`)
- [ ] Numbers formatted with thousands separator (`,`)
- [ ] Updates live on every form change
- [ ] `mix compile --warning-as-errors` passes
- [ ] Verify in browser using dev-browser skill

---

### US-017: FlightLive integration tests
**Description:** As an agent, I need integration tests for the LiveView so all user-visible behaviors are verified end-to-end.

**Acceptance Criteria:**
- [ ] Create `test/orbita_fuel_web/live/flight_live_test.exs`
- [ ] Page mounts successfully: `{:ok, view, _html}` no error
- [ ] `has_element?(view, "#flight-form")` is true on mount
- [ ] Empty state element present on mount
- [ ] One default step row present on mount
- [ ] Valid mass `28801` entered → no error element, result panel updates
- [ ] Mass `0` → inline error present
- [ ] Mass `-100` → inline error present
- [ ] Mass cleared → inline error present
- [ ] Add Step appends a new row (step count increases by 1)
- [ ] Remove step reduces count by 1
- [ ] Remove button has `disabled` attribute when only one step
- [ ] Update step action via dropdown → step reflects new action
- [ ] Update step planet via dropdown → step reflects new planet
- [ ] Apollo 11 preset → result panel contains `"51,898"`
- [ ] Mars Mission preset → result panel contains `"33,388"`
- [ ] Passenger Ship preset → result panel contains `"212,161"`
- [ ] Breakdown chain visible per step (chain element present for step 1)
- [ ] `mix test` passes

---

### US-018: Full coverage verification
**Description:** As an agent, I need ExCoveralls to confirm 100% coverage before the task is complete.

**Acceptance Criteria:**
- [ ] Run `mix coveralls`
- [ ] All relevant modules show 100% line coverage
- [ ] If any module is below 100%, add missing test cases and re-run
- [ ] Run `mix precommit` — compile, format, all tests green, no warnings
- [ ] `mix precommit` exits with code 0

---

## Functional Requirements

- FR-1: `base_fuel/3` computes `floor(mass * gravity * 0.042 - 33)` for launch, `floor(mass * gravity * 0.033 - 42)` for land; result is NOT clamped
- FR-2: `fuel_chain/3` uses `Stream.unfold/2` seeded with `mass`; stops when `base_fuel` returns `<= 0`; returns a materialized list
- FR-3: `fuel_for_step/3` returns `{Enum.sum(chain), chain}`
- FR-4: `total_fuel/2` maps over steps, accumulates `{total, chain}` per step, returns `{grand_total, per_step_list}`
- FR-5: Each step in `total_fuel/2` uses the **original spacecraft mass** — fuel from one step does NOT carry into the next step's base mass
- FR-6: `Step` embedded schema uses `Ecto.Enum` for `:action` (`:launch`, `:land`) and `:planet` (`:earth`, `:moon`, `:mars`)
- FR-7: `Flight` embedded schema uses `validate_number(:mass, greater_than: 0)` and `validate_length(:steps, min: 1)`
- FR-8: LiveView holds all state in socket assigns — no Repo calls anywhere
- FR-9: Steps use stable string IDs from `:erlang.unique_integer([:positive])` — removal by ID, not index
- FR-10: `phx-change="validate"` on the form with `phx-debounce="300"` on the mass input
- FR-11: Step dropdowns use `phx-change="update_step"` with no debounce
- FR-12: Add/Remove buttons have no debounce
- FR-13: All three reference scenarios must produce exact results: Apollo 11 → 51898, Mars Mission → 33388, Passenger Ship → 212161

---

## Non-Goals

- No database or Ecto Repo calls
- No user accounts or authentication
- No unit conversion (metric only)
- No drag-and-drop step reordering
- No multi-language / i18n
- No async Tasks or background workers (calculation is synchronous)
- No deployment configuration

---

## Technical Considerations

- Use `embedded_schema` (not `schema`) in Step and Flight — no migrations needed
- `precommit` alias already configured: `compile --warning-as-errors`, `deps.unlock --unused`, `format`, `test`
- Tailwind and Heroicons are pre-configured in `mix.exs`; use `hero-*` CSS classes for icons
- Format numbers with thousands separators using `Number.Delimit` or a simple custom helper function
- `compilers: [:phoenix_live_view] ++ Mix.compilers()` already in `mix.exs`

---

## Success Metrics

- `mix precommit` exits 0 with no warnings, no failures
- `mix coveralls` reports 100% coverage on all non-generated modules
- All three reference scenarios return exact expected fuel totals
- LiveView updates result panel within one render cycle of any input change

---

## Open Questions

- None — spec.md is complete and authoritative. All ambiguities resolved by spec.

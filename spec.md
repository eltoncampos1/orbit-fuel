# OrbitaFuel — Specification

## 1. Overview

A Phoenix 1.8 / LiveView web application that calculates the fuel required for interplanetary travel. Users build a flight path composed of sequential launch/land steps, enter a spacecraft mass, and get an instant real-time total fuel figure with the full recursive breakdown per step. No database is required — all state lives in the LiveView socket.

---

## 2. Domain Model

### 2.1 Planets

| Planet | Gravity (m/s²) |
|--------|----------------|
| Earth  | 9.807          |
| Moon   | 1.62           |
| Mars   | 3.711          |

### 2.2 Fuel Calculation Rules

**Per step (launch or land):**

```
launch_fuel(mass, gravity) = floor(mass * gravity * 0.042 - 33)
land_fuel(mass, gravity)   = floor(mass * gravity * 0.033 - 42)
```

**Recursive accumulation** — fuel itself has weight, so additional fuel is calculated until the incremental result ≤ 0.

Each step uses the **original spacecraft mass** only. Fuel from one step does NOT carry into the next step's base mass.

**Example — land Apollo 11 CSM on Earth (28801 kg, gravity 9.807):**

```
9278 fuel requires 2960 more fuel
2960 fuel requires  915 more fuel
 915 fuel requires  254 more fuel
 254 fuel requires   40 more fuel
  40 fuel requires    0 more fuel
─────────────────────────────────
Total: 13447
```

### 2.3 Validation Rules

| Field       | Rule                                     |
|-------------|------------------------------------------|
| mass        | Required, numeric, > 0                   |
| steps       | At least one step                        |
| step.action | `:launch` or `:land`                     |
| step.planet | `:earth`, `:moon`, or `:mars`            |

---

## 3. Module Architecture

```
lib/
├── orbita_fuel/
│   └── travel/
│       ├── calculator.ex   # Pure computation — Stream.unfold + Enum
│       ├── flight.ex       # embedded_schema: mass + embeds_many steps
│       └── step.ex         # embedded_schema: action + planet
└── orbita_fuel_web/
    └── live/
        └── flight_live.ex  # Single LiveView, no LiveComponents
```

No Ecto Repo calls. `Flight` and `Step` use `embedded_schema` for changeset validation only — data lives exclusively in socket assigns.

---

## 4. Module Contracts

### 4.1 `OrbitaFuel.Travel.Calculator`

**Implementation strategy: `Stream.unfold`**

`Stream.unfold` is chosen over plain recursion or `Enum.reduce_while` because:
- Lazy — generates only the values actually needed
- Naturally exposes the intermediate chain as a list (required for UI breakdown)
- Easy to test at each level: the stream, the chain, and the total are all separate concerns
- No risk of stack overflow for edge cases with very high mass values

```elixir
# Generates the fuel chain for a single step as a lazy stream
@spec fuel_chain(mass :: float(), gravity :: float(), action :: :launch | :land) :: [non_neg_integer()]

# Fuel required for a single recursive step (base only, not accumulated)
@spec base_fuel(mass :: float(), gravity :: float(), action :: :launch | :land) :: integer()

# Returns {total, chain} where chain is the list of intermediate fuel values
@spec fuel_for_step(mass :: float(), gravity :: float(), action :: :launch | :land) ::
        {total :: non_neg_integer(), chain :: [non_neg_integer()]}

# Returns {grand_total, per_step_results} where per_step_results is a list of {total, chain}
@spec total_fuel(mass :: float(), steps :: [%Step{}]) ::
        {grand_total :: non_neg_integer(), per_step :: [{non_neg_integer(), [non_neg_integer()]}]}
```

**Internal shape of `fuel_chain/3`:**

```elixir
Stream.unfold(mass, fn current ->
  fuel = base_fuel(current, gravity, action)
  if fuel <= 0, do: nil, else: {fuel, fuel}
end)
|> Enum.to_list()
```

`fuel_for_step/3` calls `fuel_chain/3`, returning `{Enum.sum(chain), chain}`.

### 4.2 `OrbitaFuel.Travel.Step`

```elixir
embedded_schema do
  field :action, Ecto.Enum, values: [:launch, :land]
  field :planet, Ecto.Enum, values: [:earth, :moon, :mars]
end

@spec changeset(t(), map()) :: Ecto.Changeset.t()
@spec gravity(planet :: atom()) :: float()
@spec planet_label(planet :: atom()) :: String.t()
@spec action_label(action :: atom()) :: String.t()
```

### 4.3 `OrbitaFuel.Travel.Flight`

```elixir
embedded_schema do
  field :mass, :float
  embeds_many :steps, Step
end

@spec changeset(t(), map()) :: Ecto.Changeset.t()
```

Validates:
- `mass` — required, `validate_number` with `greater_than: 0`
- `steps` — `validate_length` with `min: 1`
- Casts and validates each embedded `Step` changeset

### 4.4 `OrbitaFuelWeb.FlightLive`

Single LiveView mounted at `/`.

**Socket assigns:**

| Assign          | Type                                      | Description                                        |
|-----------------|-------------------------------------------|----------------------------------------------------|
| `form`          | `Phoenix.HTML.Form`                       | Derived from Flight changeset via `to_form/1`      |
| `steps`         | `[%{id, action, planet}]`                 | Ordered list with stable string IDs                |
| `result`        | `%{total, per_step} \| nil`               | nil when form is invalid                           |
| `next_step`     | `%{action: atom, planet: atom}`           | Staging area for the "Add Step" row                |

Steps use stable string IDs (generated at add time with `:erlang.unique_integer([:positive])`) to allow safe removal by ID rather than index.

**Events handled:**

| Event              | Trigger            | Debounce | Action                                       |
|--------------------|--------------------|----------|----------------------------------------------|
| `validate`         | mass input change  | 300ms    | Cast changeset, recalculate if valid         |
| `add_step`         | "Add Step" button  | none     | Append step with staged action+planet        |
| `remove_step`      | "✕" button per row | none     | Remove step by ID, recalculate               |
| `update_step`      | dropdown change    | none     | Update action or planet for a step           |
| `stage_next_step`  | staging dropdowns  | none     | Update `next_step` assign without adding     |
| `load_preset`      | preset button      | none     | Replace steps + mass with preset values      |

Recalculation runs on every state-changing event. It is synchronous and fast (pure math), so no async or Task needed.

---

## 5. Validation & Reactivity Strategy

### 5.1 Mass Input

- Uses `phx-change="validate"` with `phx-debounce="300"` — debounced because users type digit by digit
- Inline error displayed below the input when mass ≤ 0 or non-numeric
- Recalculation only triggers when changeset is valid

### 5.2 Step Dropdowns (action & planet)

- Uses `phx-change="update_step"` with **no debounce** — single-select, fires once per interaction
- Change is applied immediately, result panel updates in the same render

### 5.3 Add / Remove Buttons

- No debounce — button click events are discrete
- Remove button is `disabled` when `length(steps) == 1`

---

## 6. LiveView UI Specification

### 6.1 Page Structure

```
┌──────────────────────────────────────────────────────────────────┐
│ ◉ ORBITAFUEL                                      NASA Challenge │
│   Interplanetary Fuel Calculator                                 │
├─────────────────────────────┬────────────────────────────────────┤
│  MISSION SETUP              │  FUEL BREAKDOWN                    │
│  ───────────────            │  ────────────────                  │
│  Spacecraft Mass            │                                    │
│  ┌─────────────────────┐    │  [shown when form valid]           │
│  │ 28801            kg │    │                                    │
│  └─────────────────────┘    │  Step 1 · Launch — Earth           │
│                             │  ┌──────────────────────────────┐  │
│  Flight Path                │  │  9,278                       │  │
│  ────────────               │  │  + 2,960                     │  │
│  ┌───────────────────────┐  │  │  +   915                     │  │
│  │ [Launch ▾] [Earth ▾] ✕│  │  │  +   254                     │  │
│  │ [Land   ▾] [Moon  ▾] ✕│  │  │  +    40                     │  │
│  │ [Launch ▾] [Moon  ▾] ✕│  │  │  ─────────                   │  │
│  │ [Land   ▾] [Earth ▾] ✕│  │  │  Subtotal: 13,447 kg         │  │
│  └───────────────────────┘  │  └──────────────────────────────┘  │
│                             │                                    │
│  Add next step:             │  Step 2 · Land — Moon              │
│  [Launch ▾] [Moon ▾]        │  [breakdown...]                    │
│  [+ Add Step]               │                                    │
│                             │  Step 3 · Launch — Moon            │
│  ──────────────────         │  [breakdown...]                    │
│  Presets:                   │                                    │
│  [Apollo 11] [Mars] [Ship]  │  Step 4 · Land — Earth             │
│                             │  [breakdown...]                    │
│                             │                                    │
│                             │  ══════════════════════════════    │
│                             │  TOTAL FUEL REQUIRED               │
│                             │  51,898 kg                         │
└─────────────────────────────┴────────────────────────────────────┘
```

### 6.2 Header

- App name `ORBITAFUEL` with a subtle rocket or orbit icon (hero icon `rocket-launch`)
- Tagline: "Interplanetary Fuel Calculator"
- Right-aligned label: "NASA Challenge"
- Dark space-themed background — deep navy or near-black

### 6.3 Mission Setup Panel (left)

**Mass input:**
- Label: "Spacecraft Mass"
- `<.input type="number" field={@form[:mass]} placeholder="e.g. 28801" />`
- Unit label "kg" inside or adjacent to the input
- Inline error below on invalid value: `"Must be a positive number"`
- `phx-change="validate"` on the wrapping `<.form>`, `phx-debounce="300"` on the input

**Flight path list:**
- Section label: "Flight Path"
- Ordered list — each row contains:
  - Step number badge (1, 2, 3…)
  - Action dropdown: `[Launch | Land]`
  - Planet dropdown: `[Earth | Moon | Mars]`
  - Remove button `✕` — icon-only, `disabled` when only one step
- Rows are separated by a subtle horizontal divider
- Smooth fade-in animation on new rows (`transition-all duration-200`)

**Add step staging row:**
- Section label: "Add next step:"
- Two dropdowns (action, planet) that stage the next step without adding it
- `[+ Add Step]` button — full width, prominent
- Default staging values: `launch`, `earth`

**Presets:**
- Label: "Presets:"
- Three ghost/outline buttons: `Apollo 11`, `Mars Mission`, `Passenger Ship`
- Clicking pre-fills both mass and steps, replacing current state

### 6.4 Fuel Breakdown Panel (right)

**Empty state** (form invalid or no valid mass):
- Centered placeholder icon (e.g. `hero-calculator`)
- Text: "Enter a mass and build your flight path to see the fuel breakdown."
- Muted gray styling

**Per-step card** (one per step in the path):
- Header: `Step N · [Action] — [Planet]`
- Body: the recursive chain displayed as a vertical stack:
  ```
   9,278
  + 2,960
  +   915
  +   254
  +    40
  ───────
  13,447 kg
  ```
- Numbers right-aligned for readability
- Subtle card border, rounded corners, space between cards

**Total row:**
- Double rule separator above
- Label: `TOTAL FUEL REQUIRED`
- Value: large, bold, highlighted — e.g. `51,898 kg`
- Updates live with every form change

### 6.5 Responsive Behavior

| Breakpoint | Layout                                      |
|------------|---------------------------------------------|
| < md       | Single column — setup panel, then breakdown |
| ≥ md       | Two columns side by side, equal width       |
| ≥ lg       | Two columns, left slightly narrower (40/60) |

### 6.6 Color & Visual Theme

- Background: deep space (`#0a0f1e` or similar dark navy)
- Card surfaces: slightly lighter (`#111827`)
- Accent: electric blue or cyan (`#38bdf8`) for totals, highlights, buttons
- Success/fuel values: white or light gray for readability
- Error states: red (`#f87171`)
- Typography: clean sans-serif, monospace for numbers in the breakdown chain

---

## 7. Routing

```elixir
scope "/", OrbitaFuelWeb do
  pipe_through :browser
  live "/", FlightLive, :index
end
```

---

## 8. Test Plan & Coverage

**Target: 100% test coverage.** Use `mix test --cover` with `ExCoveralls` configured as the coverage tool.

### 8.1 `OrbitaFuel.Travel.CalculatorTest`

Every branch must be exercised:

| Test case                                               | Expected                      |
|---------------------------------------------------------|-------------------------------|
| `base_fuel` launch — nominal mass                       | positive integer              |
| `base_fuel` land — nominal mass                         | positive integer              |
| `base_fuel` result is negative → floor returns negative | negative integer (not clamped)|
| `fuel_chain` terminates when next value ≤ 0             | list ending before ≤0 value   |
| `fuel_chain` for very small mass returns empty list     | `[]`                          |
| `fuel_for_step` land Earth 28801 kg — chain             | `[9278, 2960, 915, 254, 40]`  |
| `fuel_for_step` land Earth 28801 kg — total             | `13447`                       |
| `fuel_for_step` launch Earth 28801 kg                   | matches expected value        |
| `total_fuel` Apollo 11 full path (4 steps)              | `{51898, [...]}`              |
| `total_fuel` Mars Mission (4 steps)                     | `{33388, [...]}`              |
| `total_fuel` Passenger Ship (6 steps)                   | `{212161, [...]}`             |
| `total_fuel` with empty steps list                      | `{0, []}`                     |

### 8.2 `OrbitaFuel.Travel.StepTest`

| Test case                                     | Expected                  |
|-----------------------------------------------|---------------------------|
| Valid changeset `{launch, earth}`             | `valid? == true`          |
| Valid changeset `{land, mars}`                | `valid? == true`          |
| Missing `:action`                             | error on `:action`        |
| Missing `:planet`                             | error on `:planet`        |
| Invalid action value                          | error on `:action`        |
| Invalid planet value                          | error on `:planet`        |
| `gravity(:earth)`                             | `9.807`                   |
| `gravity(:moon)`                              | `1.62`                    |
| `gravity(:mars)`                              | `3.711`                   |
| `planet_label(:earth)`                        | `"Earth"`                 |
| `action_label(:launch)`                       | `"Launch"`                |

### 8.3 `OrbitaFuel.Travel.FlightTest`

| Test case                              | Expected                  |
|----------------------------------------|---------------------------|
| Valid flight, mass > 0, one step       | `valid? == true`          |
| Valid flight, multiple steps           | `valid? == true`          |
| Mass is nil                            | error on `:mass`          |
| Mass is 0                              | error on `:mass`          |
| Mass is negative                       | error on `:mass`          |
| Mass is non-numeric string             | error on `:mass`          |
| Steps is empty list                    | error on `:steps`         |
| Step with invalid action               | error propagated to step  |

### 8.4 `OrbitaFuelWeb.FlightLiveTest`

Integration tests — test outcomes, not implementation details.

**Mount & initial state:**

| Test case                               | Assertion                                |
|-----------------------------------------|------------------------------------------|
| Page mounts successfully                | `{:ok, view, _html}` no error           |
| Form element present on mount           | `has_element?(view, "#flight-form")`    |
| Breakdown panel shows empty state       | empty state element present             |
| One default step row present            | one step row in DOM                     |

**Mass input:**

| Test case                               | Assertion                                |
|-----------------------------------------|------------------------------------------|
| Valid mass entered (28801)              | no error element, result panel updates  |
| Mass = 0                                | inline error present                    |
| Mass negative (-100)                    | inline error present                    |
| Mass cleared (empty)                    | inline error present                    |

**Step management:**

| Test case                               | Assertion                                |
|-----------------------------------------|------------------------------------------|
| Add Step appends a new row              | step count increases by 1               |
| Remove step reduces count               | step count decreases by 1               |
| Remove button disabled with 1 step      | button has `disabled` attribute         |
| Update step action via dropdown         | step action reflects new value          |
| Update step planet via dropdown         | step planet reflects new value          |

**Results:**

| Test case                               | Assertion                                |
|-----------------------------------------|------------------------------------------|
| Apollo 11 scenario shows 51898          | result panel contains "51,898"          |
| Mars Mission scenario shows 33388       | result panel contains "33,388"          |
| Passenger Ship scenario shows 212161    | result panel contains "212,161"         |
| Breakdown chain visible per step        | chain element present for step 1        |

**Presets:**

| Test case                               | Assertion                                |
|-----------------------------------------|------------------------------------------|
| Click Apollo 11 preset                  | mass = 28801, 4 steps, result = 51898   |
| Click Mars Mission preset               | mass = 14606, 4 steps, result = 33388   |
| Click Passenger Ship preset             | mass = 75432, 6 steps, result = 212161  |

---

## 9. Coverage Configuration

Add `excoveralls` to `mix.exs`:

```elixir
{:excoveralls, "~> 0.18", only: :test}
```

Add to `mix.exs` project config:

```elixir
test_coverage: [tool: ExCoveralls],
preferred_cli_env: [
  coveralls: :test,
  "coveralls.detail": :test,
  "coveralls.html": :test
]
```

Run with:

```bash
mix coveralls          # summary
mix coveralls.html     # full HTML report in cover/
```

---

## 10. Code Style

**No unnecessary comments.** Code should be self-explanatory through good naming.

- Never write comments that describe *what* the code does — well-named functions and variables already do that
- Never write comments that reference the current task, issue, or PR ("added for fuel recursion", "fix for step removal bug")
- Never write multi-line comment blocks or docstring walls
- The only acceptable comment is a single line explaining *why* something non-obvious exists: a hidden constraint, a workaround for a known edge case, or a subtle invariant that would surprise a reader
- If removing the comment would not confuse a future reader, do not write it

**Examples — never do this:**

```elixir
# Calculate the base fuel for a step
defp base_fuel(mass, gravity, :launch), do: floor(mass * gravity * 0.042 - 33)

# Loop until fuel is zero or negative
defp fuel_chain(mass, gravity, action) do
  Stream.unfold(...)
end
```

**Examples — acceptable:**

```elixir
# floor/1 is intentional — the spec requires rounding down, not rounding nearest
defp base_fuel(mass, gravity, :launch), do: floor(mass * gravity * 0.042 - 33)
```

---

## 12. Excluded from Scope

- Database / persistence
- User accounts / authentication
- Unit conversion (metric only)
- Drag-and-drop step reordering
- Multi-language / i18n

---

## 13. Acceptance Criteria

All three reference scenarios must produce exact results:

| Scenario        | Mass (kg) | Path                                                                          | Expected Fuel (kg) |
|-----------------|-----------|-------------------------------------------------------------------------------|--------------------|
| Apollo 11       | 28801     | launch Earth → land Moon → launch Moon → land Earth                          | 51898              |
| Mars Mission    | 14606     | launch Earth → land Mars → launch Mars → land Earth                          | 33388              |
| Passenger Ship  | 75432     | launch Earth → land Moon → launch Moon → land Mars → launch Mars → land Earth| 212161             |

`mix precommit` passes clean — no compiler warnings, formatted, all tests green, 100% coverage.

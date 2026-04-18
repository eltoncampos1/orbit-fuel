# OrbitaFuel

**Interplanetary Fuel Calculator** — a NASA Challenge web application built with Phoenix 1.8 and LiveView.

> This project was fully created using **Ralph's loop method** — an autonomous agent-driven development workflow where a single loop iteration generates, tests, and validates each user story end-to-end without human intervention.

---

## What it does

OrbitaFuel calculates the fuel required for multi-step spacecraft missions across Earth, Moon, and Mars. Users build a flight path composed of sequential launch and land steps, enter a spacecraft mass, and get a real-time recursive fuel breakdown per step — no page reloads, no database.

The core formula follows NASA's rocket equation:

```
launch_fuel(mass, gravity) = floor(mass × gravity × 0.042 − 33)
land_fuel(mass, gravity)   = floor(mass × gravity × 0.033 − 42)
```

Fuel is itself mass, so each step recursively accumulates additional fuel until the increment reaches zero.

### Reference scenarios

| Mission        | Mass (kg) | Path                                                                               | Total Fuel (kg) |
|----------------|-----------|------------------------------------------------------------------------------------|-----------------|
| Apollo 11      | 28,801    | Launch Earth → Land Moon → Launch Moon → Land Earth                               | 51,898          |
| Mars Mission   | 14,606    | Launch Earth → Land Mars → Launch Mars → Land Earth                               | 33,388          |
| Passenger Ship | 75,432    | Launch Earth → Land Moon → Launch Moon → Land Mars → Launch Mars → Land Earth     | 212,161         |

---

## Tech stack

| Layer       | Technology                          |
|-------------|-------------------------------------|
| Language    | Elixir ~> 1.15                      |
| Framework   | Phoenix 1.8.1 + LiveView 1.1.0      |
| Styling     | Tailwind CSS 4.1                    |
| Assets      | esbuild                             |
| Testing     | ExUnit + ExCoveralls (100% coverage)|

> No database required. `Flight` and `Step` use `embedded_schema` for changeset validation only — all state lives in the LiveView socket.

---

## Getting started

### Prerequisites

- Elixir >= 1.15

### Setup

```bash
make setup
```

### Running

```bash
make server
```

Visit [http://localhost:4000](http://localhost:4000).

---

## Available commands

| Command      | Description                   |
|--------------|-------------------------------|
| `make setup` | Fetch dependencies            |
| `make server`| Start Phoenix server          |
| `make test`  | Run the test suite            |
| `make lint`  | Check formatting and Credo    |

---

## Project structure

```
lib/
├── orbita_fuel/
│   └── travel/
│       ├── calculator.ex   # Rocket equation — Stream.unfold + Enum
│       ├── flight.ex       # embedded_schema: mass + steps
│       └── step.ex         # embedded_schema: action + planet
└── orbita_fuel_web/
    └── live/
        └── flight_live.ex  # Single LiveView, no LiveComponents
```

---

## Testing

```bash
make test

# With coverage report
mix coveralls
mix coveralls.html   # HTML report in cover/
```

Target: **100% test coverage** enforced via `mix precommit`.

---

## Built with Ralph

This entire project — from calculator logic to LiveView UI, test suite, and CI checks — was generated autonomously using **[Ralph](https://github.com/snarktank/ralph)**'s loop method.

Ralph is an autonomous development agent that takes a PRD broken into user stories and executes each one in a loop: writing code, running tests, verifying coverage, and committing only when all checks pass. No story advances until the previous one is green.

The full build history is visible in the commit log, one commit per user story (`US-001` through `US-016`).

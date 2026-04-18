defmodule OrbitaFuelWeb.FlightLive do
  use OrbitaFuelWeb, :live_view

  alias OrbitaFuel.Travel.{Calculator, Flight}

  @impl true
  def mount(_params, _session, socket) do
    default_step = new_step(:launch, :earth)
    steps = [default_step]
    form = build_form(steps)

    {:ok,
     assign(socket,
       form: form,
       steps: steps,
       result: nil,
       next_step: %{action: :launch, planet: :earth}
     )}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div id="flight-form-container">
      <.form id="flight-form" for={@form} phx-change="validate">
        <.input
          field={@form[:mass]}
          type="number"
          label="Spacecraft Mass"
          phx-debounce="300"
        />

        <div id="steps-list">
          <div
            :for={{step, idx} <- Enum.with_index(@steps)}
            id={"step-#{step.id}"}
            class="step-row"
          >
            <span class="step-number">{idx + 1}</span>
            <select
              phx-change="update_step"
              phx-value-id={step.id}
              phx-value-field="action"
            >
              <option value="launch" selected={step.action == :launch}>Launch</option>
              <option value="land" selected={step.action == :land}>Land</option>
            </select>
            <select
              phx-change="update_step"
              phx-value-id={step.id}
              phx-value-field="planet"
            >
              <option value="earth" selected={step.planet == :earth}>Earth</option>
              <option value="moon" selected={step.planet == :moon}>Moon</option>
              <option value="mars" selected={step.planet == :mars}>Mars</option>
            </select>
            <button
              type="button"
              phx-click="remove_step"
              phx-value-id={step.id}
              disabled={length(@steps) == 1}
            >
              X
            </button>
          </div>
        </div>

        <div id="staging-row">
          <label>Add next step:</label>
          <select phx-change="stage_next_step" phx-value-field="action">
            <option value="launch" selected={@next_step.action == :launch}>Launch</option>
            <option value="land" selected={@next_step.action == :land}>Land</option>
          </select>
          <select phx-change="stage_next_step" phx-value-field="planet">
            <option value="earth" selected={@next_step.planet == :earth}>Earth</option>
            <option value="moon" selected={@next_step.planet == :moon}>Moon</option>
            <option value="mars" selected={@next_step.planet == :mars}>Mars</option>
          </select>
          <button type="button" phx-click="add_step">+ Add Step</button>
        </div>

        <div id="presets">
          <button type="button" phx-click="load_preset" phx-value-name="apollo_11">Apollo 11</button>
          <button type="button" phx-click="load_preset" phx-value-name="mars_mission">Mars Mission</button>
          <button type="button" phx-click="load_preset" phx-value-name="passenger_ship">Passenger Ship</button>
        </div>
      </.form>

      <div id="result-panel">
        <div :if={is_nil(@result)} id="empty-state">
          Enter a mass and build your flight path to see the fuel breakdown.
        </div>
        <div :if={not is_nil(@result)}>
          <div
            :for={sr <- @result.step_results}
            id={"step-result-#{sr.step.id}"}
            class="step-card"
          >
            <div class="step-header">
              Step {sr.idx + 1} · {label_action(sr.step.action)} — {label_planet(sr.step.planet)}
            </div>
            <div class="step-chain" id={"chain-#{sr.step.id}"}>
              <div :for={{fuel, i} <- Enum.with_index(sr.chain)}>
                {if i == 0, do: format_number(fuel), else: "+ #{format_number(fuel)}"}
              </div>
              <hr />
              <div class="subtotal">Subtotal: {format_number(sr.total)} kg</div>
            </div>
          </div>
          <div id="total-fuel">
            TOTAL FUEL REQUIRED: {format_number(@result.total)} kg
          </div>
        </div>
      </div>
    </div>
    """
  end

  defp label_action(:launch), do: "Launch"
  defp label_action(:land), do: "Land"

  defp label_planet(:earth), do: "Earth"
  defp label_planet(:moon), do: "Moon"
  defp label_planet(:mars), do: "Mars"

  defp format_number(n) do
    n
    |> Integer.to_string()
    |> String.reverse()
    |> String.split("", trim: true)
    |> Enum.chunk_every(3)
    |> Enum.join(",")
    |> String.reverse()
  end

  defp new_step(action, planet) do
    id = to_string(:erlang.unique_integer([:positive]))
    %{id: id, action: action, planet: planet}
  end

  defp build_form(steps) do
    step_attrs = Enum.map(steps, &Map.take(&1, [:action, :planet]))
    Flight.changeset(%Flight{}, %{steps: step_attrs}) |> to_form()
  end

  defp maybe_recalculate(socket, changeset) do
    compute_result(socket, changeset, socket.assigns.steps)
  end

  defp compute_result(socket, changeset, steps) do
    if changeset.valid? do
      flight = Ecto.Changeset.apply_changes(changeset)
      {grand_total, per_step} = Calculator.total_fuel(flight.mass, flight.steps)

      step_results =
        steps
        |> Enum.with_index()
        |> Enum.zip(per_step)
        |> Enum.map(fn {{step, idx}, {total, chain}} ->
          %{step: step, idx: idx, total: total, chain: chain}
        end)

      assign(socket, result: %{total: grand_total, step_results: step_results})
    else
      assign(socket, result: nil)
    end
  end

  @impl true
  def handle_event("validate", params, socket) do
    flight_params = params["flight"] || %{}
    steps = socket.assigns.steps
    step_attrs = Enum.map(steps, &Map.take(&1, [:action, :planet]))

    changeset =
      Flight.changeset(%Flight{}, Map.put(flight_params, "steps", step_attrs))
      |> Map.put(:action, :validate)

    socket =
      socket
      |> assign(form: to_form(changeset))
      |> maybe_recalculate(changeset)

    {:noreply, socket}
  end

  @impl true
  def handle_event("add_step", _params, socket) do
    %{next_step: next_step, steps: steps} = socket.assigns
    new = new_step(next_step.action, next_step.planet)
    new_steps = steps ++ [new]

    socket =
      socket
      |> assign(steps: new_steps)
      |> update_form_and_recalculate(new_steps)

    {:noreply, socket}
  end

  @impl true
  def handle_event("remove_step", %{"id" => id}, socket) do
    new_steps = Enum.reject(socket.assigns.steps, &(&1.id == id))

    socket =
      socket
      |> assign(steps: new_steps)
      |> update_form_and_recalculate(new_steps)

    {:noreply, socket}
  end

  @impl true
  def handle_event("update_step", params, socket) do
    id = params["id"]
    field = String.to_existing_atom(params["field"])
    value = String.to_existing_atom(params["value"])

    new_steps =
      Enum.map(socket.assigns.steps, fn step ->
        if step.id == id, do: Map.put(step, field, value), else: step
      end)

    socket =
      socket
      |> assign(steps: new_steps)
      |> update_form_and_recalculate(new_steps)

    {:noreply, socket}
  end

  @impl true
  def handle_event("stage_next_step", params, socket) do
    field = String.to_existing_atom(params["field"] || "action")
    value = String.to_existing_atom(params["value"] || "launch")
    {:noreply, assign(socket, next_step: Map.put(socket.assigns.next_step, field, value))}
  end

  @impl true
  def handle_event("load_preset", %{"name" => name}, socket) do
    {mass, step_defs} = preset(name)
    step_structs = Enum.map(step_defs, fn {action, planet} -> new_step(action, planet) end)

    changeset =
      Flight.changeset(%Flight{}, %{
        mass: mass,
        steps: Enum.map(step_structs, &Map.take(&1, [:action, :planet]))
      })

    socket =
      socket
      |> assign(steps: step_structs, form: to_form(changeset))
      |> compute_result(changeset, step_structs)

    {:noreply, socket}
  end

  defp preset("apollo_11") do
    {28801, [{:launch, :earth}, {:land, :moon}, {:launch, :moon}, {:land, :earth}]}
  end

  defp preset("mars_mission") do
    {14606, [{:launch, :earth}, {:land, :mars}, {:launch, :mars}, {:land, :earth}]}
  end

  defp preset("passenger_ship") do
    {75432,
     [
       {:launch, :earth},
       {:land, :moon},
       {:launch, :moon},
       {:land, :mars},
       {:launch, :mars},
       {:land, :earth}
     ]}
  end

  defp update_form_and_recalculate(socket, steps) do
    mass =
      socket.assigns.form.params["mass"] ||
        get_in(socket.assigns.form.source.changes, [:mass])

    step_attrs = Enum.map(steps, &Map.take(&1, [:action, :planet]))

    changeset =
      Flight.changeset(%Flight{}, %{"mass" => mass, "steps" => step_attrs})
      |> Map.put(:action, :validate)

    socket
    |> assign(form: to_form(changeset))
    |> compute_result(changeset, steps)
  end
end

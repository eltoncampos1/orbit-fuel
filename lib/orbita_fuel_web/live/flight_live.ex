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
    <div class="min-h-screen bg-[#0a0f1e] text-white flex flex-col">
      <%!-- Header --%>
      <header class="flex items-center justify-between px-8 py-4 border-b border-white/10">
        <div class="flex items-center gap-3">
          <.icon name="hero-rocket-launch" class="size-7 text-indigo-400" />
          <span class="text-xl font-bold tracking-widest text-white">ORBITAFUEL</span>
          <span class="text-sm text-gray-400 ml-2">Interplanetary Fuel Calculator</span>
        </div>
        <span class="text-xs font-semibold text-indigo-300 tracking-widest uppercase">NASA Challenge</span>
      </header>

      <div class="flex flex-1 overflow-hidden">
        <%!-- Left panel: mission setup --%>
        <div class="w-full max-w-lg p-8 border-r border-white/10 overflow-y-auto flex flex-col gap-6">
          <%!-- Mass input (inside form for validate event) --%>
          <.form id="flight-form" for={@form} phx-change="validate">
            <div class="mb-2">
              <label class="block text-sm font-semibold text-gray-300 mb-1">Spacecraft Mass</label>
              <div class="flex items-center gap-2">
                <input
                  id={@form[:mass].id}
                  name={@form[:mass].name}
                  type="number"
                  value={@form[:mass].value}
                  phx-debounce="300"
                  class="input input-bordered bg-white/5 border-white/20 text-white w-full"
                  placeholder="e.g. 28801"
                />
                <span class="text-gray-400 text-sm whitespace-nowrap">kg</span>
              </div>
              <p :for={err <- Enum.map(@form[:mass].errors, &translate_error(&1))} class="mt-1 text-sm text-error">
                {err}
              </p>
            </div>
          </.form>

          <%!-- Flight path (outside form so phx-value-* params work correctly) --%>
          <div>
            <h3 class="text-sm font-semibold text-gray-300 mb-3 uppercase tracking-wider">Flight Path</h3>
            <ol id="steps-list" class="flex flex-col gap-2">
              <li
                :for={{step, idx} <- Enum.with_index(@steps)}
                id={"step-#{step.id}"}
                class="flex items-center gap-2 bg-white/5 rounded-lg px-3 py-2"
              >
                <span class="badge badge-sm badge-outline text-indigo-300 border-indigo-400 shrink-0">
                  {idx + 1}
                </span>
                <form phx-change="update_step" id={"step-form-#{step.id}"} class="flex items-center gap-2 flex-1">
                  <input type="hidden" name="step_id" value={step.id} />
                  <select
                    name="action"
                    class="select select-sm bg-transparent border-white/20 text-white flex-1"
                  >
                    <option value="launch" selected={step.action == :launch}>Launch</option>
                    <option value="land" selected={step.action == :land}>Land</option>
                  </select>
                  <select
                    name="planet"
                    class="select select-sm bg-transparent border-white/20 text-white flex-1"
                  >
                    <option value="earth" selected={step.planet == :earth}>Earth</option>
                    <option value="moon" selected={step.planet == :moon}>Moon</option>
                    <option value="mars" selected={step.planet == :mars}>Mars</option>
                  </select>
                </form>
                <button
                  type="button"
                  phx-click="remove_step"
                  phx-value-id={step.id}
                  disabled={length(@steps) == 1}
                  class="btn btn-ghost btn-xs text-red-400 hover:text-red-300 disabled:opacity-30"
                >
                  ✕
                </button>
              </li>
            </ol>
          </div>

          <%!-- Staging row --%>
          <div id="staging-row" class="flex items-center gap-2">
            <span class="text-sm text-gray-400 whitespace-nowrap">Add next step:</span>
            <select
              phx-change="stage_next_step"
              phx-value-field="action"
              class="select select-sm bg-white/5 border-white/20 text-white flex-1"
            >
              <option value="launch" selected={@next_step.action == :launch}>Launch</option>
              <option value="land" selected={@next_step.action == :land}>Land</option>
            </select>
            <select
              phx-change="stage_next_step"
              phx-value-field="planet"
              class="select select-sm bg-white/5 border-white/20 text-white flex-1"
            >
              <option value="earth" selected={@next_step.planet == :earth}>Earth</option>
              <option value="moon" selected={@next_step.planet == :moon}>Moon</option>
              <option value="mars" selected={@next_step.planet == :mars}>Mars</option>
            </select>
            <button type="button" phx-click="add_step" class="btn btn-sm btn-outline border-indigo-500 text-indigo-300 hover:bg-indigo-800 whitespace-nowrap">
              + Add Step
            </button>
          </div>

          <%!-- Presets --%>
          <div id="presets">
            <h3 class="text-sm font-semibold text-gray-300 mb-3 uppercase tracking-wider">Presets</h3>
            <div class="flex flex-wrap gap-2">
              <button type="button" phx-click="load_preset" phx-value-name="apollo_11"
                class="btn btn-sm bg-white/10 hover:bg-white/20 text-white border-white/20">
                Apollo 11
              </button>
              <button type="button" phx-click="load_preset" phx-value-name="mars_mission"
                class="btn btn-sm bg-white/10 hover:bg-white/20 text-white border-white/20">
                Mars Mission
              </button>
              <button type="button" phx-click="load_preset" phx-value-name="passenger_ship"
                class="btn btn-sm bg-white/10 hover:bg-white/20 text-white border-white/20">
                Passenger Ship
              </button>
            </div>
          </div>
        </div>

        <%!-- Right panel: fuel breakdown --%>
        <div id="result-panel" class="flex-1 p-8 overflow-y-auto">
          <div :if={is_nil(@result)} id="empty-state" class="flex flex-col items-center justify-center h-full text-center gap-4">
            <.icon name="hero-calculator" class="size-16 text-gray-600" />
            <p class="text-gray-400 max-w-xs">
              Enter a mass and build your flight path to see the fuel breakdown.
            </p>
          </div>

          <div :if={not is_nil(@result)} class="flex flex-col gap-6">
            <div
              :for={sr <- @result.step_results}
              id={"step-result-#{sr.step.id}"}
              class="step-card bg-white/5 rounded-xl p-5 border border-white/10"
            >
              <h4 class="font-semibold text-indigo-300 mb-3">
                Step {sr.idx + 1} · {label_action(sr.step.action)} — {label_planet(sr.step.planet)}
              </h4>
              <div id={"chain-#{sr.step.id}"} class="font-mono text-sm flex flex-col gap-1 text-right">
                <div :for={{fuel, i} <- Enum.with_index(sr.chain)} class="text-gray-200">
                  {if i == 0, do: format_number(fuel), else: "+ #{format_number(fuel)}"}
                </div>
                <hr class="border-white/20 my-1" />
                <div class="text-gray-400">Subtotal: {format_number(sr.total)} kg</div>
              </div>
            </div>

            <div id="total-fuel" class="border-t-2 border-b-2 border-white/30 py-4 mt-2">
              <div class="flex items-baseline justify-between">
                <span class="text-sm font-bold tracking-widest uppercase text-gray-300">Total Fuel Required</span>
                <span class="text-3xl font-bold text-white font-mono">{format_number(@result.total)} kg</span>
              </div>
            </div>
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
    id = params["step_id"]
    action = params["action"] && String.to_existing_atom(params["action"])
    planet = params["planet"] && String.to_existing_atom(params["planet"])

    new_steps =
      Enum.map(socket.assigns.steps, fn step ->
        if step.id == id do
          step
          |> then(fn s -> if action, do: Map.put(s, :action, action), else: s end)
          |> then(fn s -> if planet, do: Map.put(s, :planet, planet), else: s end)
        else
          step
        end
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

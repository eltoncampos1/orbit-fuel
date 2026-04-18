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
      </.form>
    </div>
    """
  end

  defp new_step(action, planet) do
    id = to_string(:erlang.unique_integer([:positive]))
    %{id: id, action: action, planet: planet}
  end

  defp build_form(steps) do
    step_attrs = Enum.map(steps, &Map.take(&1, [:action, :planet]))

    Flight.changeset(%Flight{}, %{steps: step_attrs})
    |> to_form()
  end

  defp recalculate(socket) do
    %{steps: steps, form: form} = socket.assigns

    changeset =
      Flight.changeset(%Flight{}, %{
        mass: form.params["mass"] || form.source.changes[:mass],
        steps: Enum.map(steps, &Map.take(&1, [:action, :planet]))
      })

    if changeset.valid? do
      flight = Ecto.Changeset.apply_changes(changeset)
      {grand_total, per_step} = Calculator.total_fuel(flight.mass, flight.steps)
      assign(socket, result: %{total: grand_total, per_step: per_step})
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
      |> update_form(new_steps)
      |> recalculate()

    {:noreply, socket}
  end

  @impl true
  def handle_event("remove_step", %{"id" => id}, socket) do
    new_steps = Enum.reject(socket.assigns.steps, &(&1.id == id))

    socket =
      socket
      |> assign(steps: new_steps)
      |> update_form(new_steps)
      |> recalculate()

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
      |> update_form(new_steps)
      |> recalculate()

    {:noreply, socket}
  end

  @impl true
  def handle_event("stage_next_step", params, socket) do
    action = String.to_existing_atom(params["action"] || "launch")
    planet = String.to_existing_atom(params["planet"] || "earth")
    {:noreply, assign(socket, next_step: %{action: action, planet: planet})}
  end

  @impl true
  def handle_event("load_preset", %{"name" => name}, socket) do
    {mass, steps} = preset(name)

    step_structs = Enum.map(steps, fn {action, planet} -> new_step(action, planet) end)

    changeset =
      Flight.changeset(%Flight{}, %{
        mass: mass,
        steps: Enum.map(step_structs, &Map.take(&1, [:action, :planet]))
      })

    socket =
      socket
      |> assign(steps: step_structs, form: to_form(changeset))
      |> recalculate()

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

  defp update_form(socket, steps) do
    mass = socket.assigns.form.params["mass"] || get_in(socket.assigns.form.source.changes, [:mass])
    step_attrs = Enum.map(steps, &Map.take(&1, [:action, :planet]))

    changeset =
      Flight.changeset(%Flight{}, %{"mass" => mass, "steps" => step_attrs})
      |> Map.put(:action, :validate)

    assign(socket, form: to_form(changeset))
  end

  defp maybe_recalculate(socket, changeset) do
    if changeset.valid? do
      flight = Ecto.Changeset.apply_changes(changeset)
      {grand_total, per_step} = Calculator.total_fuel(flight.mass, flight.steps)
      assign(socket, result: %{total: grand_total, per_step: per_step})
    else
      assign(socket, result: nil)
    end
  end
end

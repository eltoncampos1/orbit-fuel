defmodule OrbitaFuel.Travel.Calculator do
  @moduledoc false

  def base_fuel(mass, gravity, :launch), do: floor(mass * gravity * 0.042 - 33)
  def base_fuel(mass, gravity, :land), do: floor(mass * gravity * 0.033 - 42)

  def fuel_chain(mass, gravity, action) do
    Stream.unfold(mass, fn current ->
      fuel = base_fuel(current, gravity, action)
      if fuel <= 0, do: nil, else: {fuel, fuel}
    end)
    |> Enum.to_list()
  end

  def fuel_for_step(mass, gravity, action) do
    chain = fuel_chain(mass, gravity, action)
    {Enum.sum(chain), chain}
  end

  def total_fuel(_mass, []), do: {0, []}

  def total_fuel(mass, steps) do
    alias OrbitaFuel.Travel.Step

    # Process steps in reverse: last step uses base mass; each earlier step
    # carries fuel needed for all subsequent steps (rocket equation).
    {grand_total, per_step} =
      Enum.reduce(Enum.reverse(steps), {0, []}, fn step, {acc_fuel, results} ->
        {f, chain} = fuel_for_step(mass + acc_fuel, Step.gravity(step.planet), step.action)
        {acc_fuel + f, [{f, chain} | results]}
      end)

    {grand_total, per_step}
  end
end

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
end

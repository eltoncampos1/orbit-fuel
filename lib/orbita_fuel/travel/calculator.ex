defmodule OrbitaFuel.Travel.Calculator do
  @moduledoc false

  def base_fuel(mass, gravity, :launch), do: floor(mass * gravity * 0.042 - 33)
  def base_fuel(mass, gravity, :land), do: floor(mass * gravity * 0.033 - 42)
end

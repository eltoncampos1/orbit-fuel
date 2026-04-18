defmodule OrbitaFuel.Travel.Step do
  @moduledoc false

  use Ecto.Schema
  import Ecto.Changeset

  embedded_schema do
    field :action, Ecto.Enum, values: [:launch, :land]
    field :planet, Ecto.Enum, values: [:earth, :moon, :mars]
  end

  def changeset(step \\ %__MODULE__{}, attrs) do
    step
    |> cast(attrs, [:action, :planet])
    |> validate_required([:action, :planet])
  end

  def gravity(:earth), do: 9.807
  def gravity(:moon), do: 1.62
  def gravity(:mars), do: 3.711

  def planet_label(:earth), do: "Earth"
  def planet_label(:moon), do: "Moon"
  def planet_label(:mars), do: "Mars"

  def action_label(:launch), do: "Launch"
  def action_label(:land), do: "Land"
end

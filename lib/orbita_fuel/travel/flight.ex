defmodule OrbitaFuel.Travel.Flight do
  @moduledoc false

  use Ecto.Schema
  import Ecto.Changeset

  alias OrbitaFuel.Travel.Step

  embedded_schema do
    field :mass, :float
    embeds_many :steps, Step
  end

  def changeset(flight \\ %__MODULE__{}, attrs) do
    flight
    |> cast(attrs, [:mass])
    |> validate_required([:mass])
    |> validate_number(:mass, greater_than: 0)
    |> cast_embed(:steps, required: true)
    |> validate_length(:steps, min: 1)
  end
end

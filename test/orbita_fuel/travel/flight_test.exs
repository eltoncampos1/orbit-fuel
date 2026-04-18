defmodule OrbitaFuel.Travel.FlightTest do
  use ExUnit.Case, async: true

  alias OrbitaFuel.Travel.Flight

  defp valid_step, do: %{action: :launch, planet: :earth}

  describe "changeset/2" do
    test "valid flight with one step → valid? == true" do
      cs = Flight.changeset(%Flight{}, %{mass: 28801.0, steps: [valid_step()]})
      assert cs.valid?
    end

    test "valid flight with multiple steps → valid? == true" do
      cs =
        Flight.changeset(%Flight{}, %{
          mass: 28801.0,
          steps: [valid_step(), %{action: :land, planet: :moon}]
        })

      assert cs.valid?
    end

    test "mass is nil → error on :mass" do
      cs = Flight.changeset(%Flight{}, %{steps: [valid_step()]})
      refute cs.valid?
      assert cs.errors[:mass]
    end

    test "mass is 0 → error on :mass" do
      cs = Flight.changeset(%Flight{}, %{mass: 0, steps: [valid_step()]})
      refute cs.valid?
      assert cs.errors[:mass]
    end

    test "mass is -100 → error on :mass" do
      cs = Flight.changeset(%Flight{}, %{mass: -100, steps: [valid_step()]})
      refute cs.valid?
      assert cs.errors[:mass]
    end

    test "mass is non-numeric string → error on :mass" do
      cs = Flight.changeset(%Flight{}, %{mass: "abc", steps: [valid_step()]})
      refute cs.valid?
      assert cs.errors[:mass]
    end

    test "steps is empty list → error on :steps" do
      cs = Flight.changeset(%Flight{}, %{mass: 28801.0, steps: []})
      refute cs.valid?
      assert cs.errors[:steps]
    end

    test "step with invalid action inside flight → error propagated" do
      cs =
        Flight.changeset(%Flight{}, %{
          mass: 28801.0,
          steps: [%{action: "fly", planet: :earth}]
        })

      refute cs.valid?
    end
  end
end

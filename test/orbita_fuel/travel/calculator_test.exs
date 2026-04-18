defmodule OrbitaFuel.Travel.CalculatorTest do
  use ExUnit.Case, async: true

  alias OrbitaFuel.Travel.{Calculator, Step}

  describe "base_fuel/3" do
    test "launch with nominal mass returns positive integer" do
      assert Calculator.base_fuel(28801, 9.807, :launch) == 11829
    end

    test "land with nominal mass returns positive integer" do
      assert Calculator.base_fuel(28801, 9.807, :land) == 9278
    end

    test "result is negative for very small mass (not clamped)" do
      result = Calculator.base_fuel(1, 9.807, :launch)
      assert is_integer(result)
      assert result < 0
    end
  end

  describe "fuel_chain/3" do
    test "terminates and returns a list ending before the <= 0 value" do
      chain = Calculator.fuel_chain(28801, 9.807, :land)
      assert is_list(chain)
      assert Enum.all?(chain, &(&1 > 0))
      assert List.last(chain) > 0
    end

    test "returns [] for mass where first base_fuel is <= 0" do
      assert Calculator.fuel_chain(1, 9.807, :launch) == []
    end
  end

  describe "fuel_for_step/3" do
    test "land Earth 28801 kg — chain equals [9278, 2960, 915, 254, 40]" do
      {_total, chain} = Calculator.fuel_for_step(28801, 9.807, :land)
      assert chain == [9278, 2960, 915, 254, 40]
    end

    test "land Earth 28801 kg — total equals 13447" do
      {total, _chain} = Calculator.fuel_for_step(28801, 9.807, :land)
      assert total == 13447
    end

    test "launch Earth 28801 kg returns expected values" do
      {total, chain} = Calculator.fuel_for_step(28801, 9.807, :launch)
      assert total == 19772
      assert chain == [11829, 4839, 1960, 774, 285, 84, 1]
    end
  end

  describe "total_fuel/2" do
    test "Apollo 11 four steps returns {51898, _}" do
      steps = [
        %Step{action: :launch, planet: :earth},
        %Step{action: :land, planet: :moon},
        %Step{action: :launch, planet: :moon},
        %Step{action: :land, planet: :earth}
      ]

      assert {51898, _} = Calculator.total_fuel(28801, steps)
    end

    test "Mars Mission four steps returns {33388, _}" do
      steps = [
        %Step{action: :launch, planet: :earth},
        %Step{action: :land, planet: :mars},
        %Step{action: :launch, planet: :mars},
        %Step{action: :land, planet: :earth}
      ]

      assert {33388, _} = Calculator.total_fuel(14606, steps)
    end

    test "Passenger Ship six steps returns {212161, _}" do
      steps = [
        %Step{action: :launch, planet: :earth},
        %Step{action: :land, planet: :moon},
        %Step{action: :launch, planet: :moon},
        %Step{action: :land, planet: :mars},
        %Step{action: :launch, planet: :mars},
        %Step{action: :land, planet: :earth}
      ]

      assert {212_161, _} = Calculator.total_fuel(75432, steps)
    end

    test "empty steps list returns {0, []}" do
      assert Calculator.total_fuel(28801, []) == {0, []}
    end
  end
end

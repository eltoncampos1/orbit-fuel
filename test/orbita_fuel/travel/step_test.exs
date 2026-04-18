defmodule OrbitaFuel.Travel.StepTest do
  use ExUnit.Case, async: true

  alias OrbitaFuel.Travel.Step

  describe "changeset/2" do
    test "valid {:launch, :earth} → valid? == true" do
      cs = Step.changeset(%Step{}, %{action: :launch, planet: :earth})
      assert cs.valid?
    end

    test "valid {:land, :mars} → valid? == true" do
      cs = Step.changeset(%Step{}, %{action: :land, planet: :mars})
      assert cs.valid?
    end

    test "missing :action → error on :action" do
      cs = Step.changeset(%Step{}, %{planet: :earth})
      refute cs.valid?
      assert cs.errors[:action]
    end

    test "missing :planet → error on :planet" do
      cs = Step.changeset(%Step{}, %{action: :launch})
      refute cs.valid?
      assert cs.errors[:planet]
    end

    test "invalid action value → error on :action" do
      cs = Step.changeset(%Step{}, %{action: "fly", planet: :earth})
      refute cs.valid?
      assert cs.errors[:action]
    end

    test "invalid planet value → error on :planet" do
      cs = Step.changeset(%Step{}, %{action: :launch, planet: "venus"})
      refute cs.valid?
      assert cs.errors[:planet]
    end
  end

  describe "gravity/1" do
    test "earth returns 9.807" do
      assert Step.gravity(:earth) == 9.807
    end

    test "moon returns 1.62" do
      assert Step.gravity(:moon) == 1.62
    end

    test "mars returns 3.711" do
      assert Step.gravity(:mars) == 3.711
    end
  end

  describe "planet_label/1" do
    test "earth returns Earth" do
      assert Step.planet_label(:earth) == "Earth"
    end

    test "moon returns Moon" do
      assert Step.planet_label(:moon) == "Moon"
    end

    test "mars returns Mars" do
      assert Step.planet_label(:mars) == "Mars"
    end
  end

  describe "action_label/1" do
    test "launch returns Launch" do
      assert Step.action_label(:launch) == "Launch"
    end

    test "land returns Land" do
      assert Step.action_label(:land) == "Land"
    end
  end
end

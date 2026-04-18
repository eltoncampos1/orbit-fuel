defmodule OrbitaFuelWeb.FlightLiveTest do
  use OrbitaFuelWeb.ConnCase

  import Phoenix.LiveViewTest

  describe "mount" do
    test "page mounts successfully", %{conn: conn} do
      assert {:ok, _view, _html} = live(conn, "/")
    end

    test "flight-form is present on mount", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/")
      assert has_element?(view, "#flight-form")
    end

    test "empty state is present on mount", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/")
      assert has_element?(view, "#empty-state")
    end

    test "one default step row is present on mount", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/")
      assert has_element?(view, "#steps-list li")
      step_count = view |> element("#steps-list") |> render() |> count_items("<li")
      assert step_count == 1
    end
  end

  describe "validate event" do
    test "valid mass 28801 updates result panel", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/")

      view
      |> form("#flight-form", flight: %{mass: "28801"})
      |> render_change()

      refute has_element?(view, "#empty-state")
      assert has_element?(view, "#total-fuel")
    end

    test "mass 0 shows inline error", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/")

      html =
        view
        |> form("#flight-form", flight: %{mass: "0"})
        |> render_change()

      assert html =~ "must be greater than"
    end

    test "mass -100 shows inline error", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/")

      html =
        view
        |> form("#flight-form", flight: %{mass: "-100"})
        |> render_change()

      assert html =~ "must be greater than"
    end

    test "mass cleared shows inline error", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/")

      html =
        view
        |> form("#flight-form", flight: %{mass: ""})
        |> render_change()

      assert html =~ "can&#39;t be blank" or html =~ "can't be blank"
    end
  end

  describe "step management" do
    test "add_step appends a new step row", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/")

      before_count =
        view |> element("#steps-list") |> render() |> count_items("<li")

      view |> element("button", "+ Add Step") |> render_click()

      after_count =
        view |> element("#steps-list") |> render() |> count_items("<li")

      assert after_count == before_count + 1
    end

    test "remove_step reduces step count", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/")

      view |> element("button", "+ Add Step") |> render_click()

      before_count =
        view |> element("#steps-list") |> render() |> count_items("<li")

      view
      |> element("#steps-list li:last-child button[phx-click='remove_step']")
      |> render_click()

      after_count =
        view |> element("#steps-list") |> render() |> count_items("<li")

      assert after_count == before_count - 1
    end

    test "remove button is disabled when only one step", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/")

      assert has_element?(view, "button[phx-click='remove_step'][disabled]")
    end

    test "update step action changes step", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/")

      html =
        view
        |> element("#steps-list li:first-child form[phx-change='update_step']")
        |> render_change(%{action: "land"})

      assert html =~ "Land"
    end

    test "update step planet changes step", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/")

      html =
        view
        |> element("#steps-list li:first-child form[phx-change='update_step']")
        |> render_change(%{planet: "mars"})

      assert html =~ "Mars"
    end
  end

  describe "presets" do
    test "Apollo 11 preset shows 51,898 in result panel", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/")

      view |> element("button", "Apollo 11") |> render_click()

      assert has_element?(view, "#total-fuel")
      assert render(view) =~ "51,898"
    end

    test "Mars Mission preset shows 33,388 in result panel", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/")

      view |> element("button", "Mars Mission") |> render_click()

      assert render(view) =~ "33,388"
    end

    test "Passenger Ship preset shows 212,161 in result panel", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/")

      view |> element("button", "Passenger Ship") |> render_click()

      assert render(view) =~ "212,161"
    end
  end

  describe "breakdown display" do
    test "chain element is present for step 1 when result is set", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/")

      view |> element("button", "Apollo 11") |> render_click()

      assert has_element?(view, "[id^='chain-']")
    end
  end

  defp count_items(html, tag) do
    html |> String.split(tag) |> length() |> Kernel.-(1)
  end
end

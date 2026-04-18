defmodule OrbitaFuelWeb.PageControllerTest do
  use OrbitaFuelWeb.ConnCase

  test "GET / redirects to FlightLive", %{conn: conn} do
    conn = get(conn, ~p"/")
    assert html_response(conn, 200) =~ "ORBITAFUEL"
  end
end

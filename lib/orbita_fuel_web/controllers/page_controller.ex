defmodule OrbitaFuelWeb.PageController do
  use OrbitaFuelWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end

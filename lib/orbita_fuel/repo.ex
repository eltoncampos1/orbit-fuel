defmodule OrbitaFuel.Repo do
  use Ecto.Repo,
    otp_app: :orbita_fuel,
    adapter: Ecto.Adapters.Postgres
end

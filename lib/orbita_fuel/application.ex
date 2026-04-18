defmodule OrbitaFuel.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      OrbitaFuelWeb.Telemetry,
      OrbitaFuel.Repo,
      {DNSCluster, query: Application.get_env(:orbita_fuel, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: OrbitaFuel.PubSub},
      # Start a worker by calling: OrbitaFuel.Worker.start_link(arg)
      # {OrbitaFuel.Worker, arg},
      # Start to serve requests, typically the last entry
      OrbitaFuelWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: OrbitaFuel.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    OrbitaFuelWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end

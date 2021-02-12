defmodule PlugSessionDbStore.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @doc false
  def start(_type, _args) do
    children = [
      # Start the Ecto repository
      PlugSessionDbStore.Repo,
      # Start the Telemetry supervisor
      PlugSessionDbStoreWeb.Telemetry,
      # Start the PubSub system
      {Phoenix.PubSub, name: PlugSessionDbStore.PubSub},
      # Start the Endpoint (http/https)
      PlugSessionDbStoreWeb.Endpoint
      # Start a worker by calling: PlugSessionDbStore.Worker.start_link(arg)
      # {PlugSessionDbStore.Worker, arg}
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: PlugSessionDbStore.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  def config_change(changed, _new, removed) do
    PlugSessionDbStoreWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end

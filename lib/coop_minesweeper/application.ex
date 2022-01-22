defmodule CoopMinesweeper.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      # Start the Ecto repository
      CoopMinesweeper.Repo,
      # Start the Telemetry supervisor
      CoopMinesweeperWeb.Telemetry,
      # Start the PubSub system
      {Phoenix.PubSub, name: CoopMinesweeper.PubSub},
      # Start the Endpoint (http/https)
      CoopMinesweeperWeb.Endpoint
      # Start a worker by calling: CoopMinesweeper.Worker.start_link(arg)
      # {CoopMinesweeper.Worker, arg}
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: CoopMinesweeper.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    CoopMinesweeperWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end

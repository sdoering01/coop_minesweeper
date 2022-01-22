defmodule CoopMinesweeper.Game.Supervisor do
  @moduledoc """
  Supervises the processes that are needed to save games in memory.
  """

  use Supervisor

  def start_link(opts) do
    Supervisor.start_link(__MODULE__, :ok, opts)
  end

  @impl true
  def init(:ok) do
    children = [
      {DynamicSupervisor, name: CoopMinesweeper.GameSupervisor, strategy: :one_for_one},
      {Registry, name: CoopMinesweeper.GameRegistry, keys: :unique}
    ]

    Supervisor.init(children, strategy: :one_for_all)
  end
end

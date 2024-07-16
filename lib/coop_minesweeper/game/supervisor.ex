defmodule CoopMinesweeper.Game.Supervisor do
  @moduledoc """
  Supervises the processes that are needed to save games in memory.
  """

  use Supervisor

  def start_link(init_arg) do
    Supervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  @impl true
  def init(_init_arg) do
    children = [
      CoopMinesweeper.Game.GameSupervisor,
      {Registry, name: CoopMinesweeper.Game.GameRegistry, keys: :unique}
    ]

    Supervisor.init(children, strategy: :one_for_all)
  end
end

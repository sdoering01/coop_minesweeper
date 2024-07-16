defmodule CoopMinesweeper.Game.GameInstanceSupervisor do
  @moduledoc """
  Supervises the processes of a given game instance. Currently this includes
  the game process itself and a supervisor for bots.
  """

  use Supervisor

  def start_link(opts) do
    game_opts = Keyword.fetch!(opts, :game_opts)

    Supervisor.start_link(__MODULE__, game_opts, opts)
  end

  @impl true
  def init(game_opts) do
    children = [
      {CoopMinesweeper.Game.Game, significant: true, restart: :temporary, game_opts: game_opts},
      CoopMinesweeper.Game.BotSupervisor
    ]

    Supervisor.init(children, auto_shutdown: :any_significant, strategy: :one_for_all)
  end

  def get_game(supervisor) do
    get_child(supervisor, CoopMinesweeper.Game.Game)
  end

  def get_bot_supervisor(supervisor) do
    get_child(supervisor, CoopMinesweeper.Game.BotSupervisor)
  end

  defp get_child(supervisor, child_module) do
    {_id, pid, __type, _modules} =
      Supervisor.which_children(supervisor)
      |> Enum.find(:not_found, fn {id, _, _, _} -> id == child_module end)

    pid
  end
end

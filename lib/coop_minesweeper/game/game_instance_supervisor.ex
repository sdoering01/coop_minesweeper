defmodule CoopMinesweeper.Game.GameInstanceSupervisor do
  @moduledoc """
  Supervises the processes of a given game instance. Currently this includes
  the game process itself and a supervisor for bots.
  """

  use Supervisor, restart: :transient

  def start_link(opts) do
    game_opts = Keyword.fetch!(opts, :game_opts)

    opts = Keyword.put_new(opts, :auto_shutdown, :any_significant)

    Supervisor.start_link(__MODULE__, game_opts, opts)
  end

  @impl true
  def init(game_opts) do
    children = [
      {CoopMinesweeper.Game.Game, game_opts: game_opts},
      CoopMinesweeper.Game.BotSupervisor
    ]

    Supervisor.init(children,
      auto_shutdown: :any_significant,
      strategy: :one_for_one
    )
  end

  def get_game(supervisor) do
    get_child(supervisor, CoopMinesweeper.Game.Game)
  end

  def get_bot_supervisor(supervisor) do
    get_child(supervisor, CoopMinesweeper.Game.BotSupervisor)
  end

  def add_bot(supervisor, game_id) do
    bot_supervisor = get_bot_supervisor(supervisor)

    DynamicSupervisor.start_child(
      bot_supervisor,
      {CoopMinesweeper.Game.Bot, game_id: game_id}
    )
  end

  defp get_child(supervisor, child_module) do
    {_id, pid, __type, _modules} =
      Supervisor.which_children(supervisor)
      |> Enum.find(:not_found, fn {id, _, _, _} -> id == child_module end)

    pid
  end
end

defmodule CoopMinesweeper.Game.GameInstanceSupervisor do
  @moduledoc """
  Supervises the processes of a given game instance. Currently this includes
  the game process itself and a supervisor for bots.
  """

  use Supervisor, restart: :transient

  alias CoopMinesweeper.Game.BotSupervisor

  @max_bots_per_game 3

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

    if BotSupervisor.count_bots(bot_supervisor) >= @max_bots_per_game do
      {:error, :max_bots_reached}
    else
      {:ok, _pid} =
        DynamicSupervisor.start_child(
          bot_supervisor,
          {CoopMinesweeper.Game.Bot, game_id: game_id}
        )

      :ok
    end
  end

  def remove_bot(game_id, bot_id) do
    case Registry.lookup(CoopMinesweeper.Game.BotRegistry, {game_id, bot_id}) do
      [{pid, _value}] -> Process.exit(pid, :shutdown)
      _ -> nil
    end
  end

  defp get_child(supervisor, child_module) do
    {_id, pid, __type, _modules} =
      Supervisor.which_children(supervisor)
      |> Enum.find(:not_found, fn {id, _, _, _} -> id == child_module end)

    pid
  end
end

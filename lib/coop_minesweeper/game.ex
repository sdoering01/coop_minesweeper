defmodule CoopMinesweeper.Game do
  alias CoopMinesweeper.Game.{GameRegistry, Game, Field}
  alias CoopMinesweeperWeb.Presence

  @doc """
  Returns a capped amount of fields that are public and running.
  """
  def list_public_fields() do
    GameRegistry.list_game_pids()
    |> Stream.map(&Game.get_field/1)
    |> Stream.filter(fn
      %Field{state: :running, visibility: :public} -> true
      %Field{} -> false
    end)
    |> Stream.map(fn %Field{id: id} = field ->
      topic = "game:" <> id

      player_count =
        topic
        |> Presence.list()
        |> map_size()

      %{player_count: player_count, field: field}
    end)
    |> Stream.take(10)
    |> Enum.to_list()
  end
end

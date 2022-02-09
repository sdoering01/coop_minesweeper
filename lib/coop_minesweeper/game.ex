defmodule CoopMinesweeper.Game do
  alias CoopMinesweeper.Game.{GameRegistry, Game, Field}
  alias CoopMinesweeperWeb.Presence

  @doc """
  Returns a capped amount of fields that are public and running.
  """
  @spec list_public_fields() :: [%{player_count: non_neg_integer(), field: Field.t()}]
  def list_public_fields() do
    GameRegistry.list_game_pids()
    |> Stream.map(&Game.get_field/1)
    |> Stream.filter(fn
      %Field{state: :running, visibility: :public} -> true
      %Field{} -> false
    end)
    |> Stream.map(fn field ->
      %{player_count: get_game_player_count(field.id), field: field}
    end)
    |> Stream.take(10)
    |> Enum.to_list()
  end

  @doc """
  Returns player count of the game with the given id.
  """
  @spec get_game_player_count(id :: String.t()) :: non_neg_integer()
  def get_game_player_count(id) do
    topic = "game:" <> id

    topic
    |> Presence.list()
    |> map_size()
  end
end

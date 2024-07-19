defmodule CoopMinesweeper.Game.GameRegistry do
  @moduledoc """
  This module is responsible for creating and managing the supervisors of game
  instances. The game instance itself is supervised by its game instance
  supervisor, along with other things like the bot supervisor of each game.
  """

  alias CoopMinesweeper.Game.{GameInstanceSupervisor, Game, Field}

  @type not_found_error() :: {:error, :not_found_error}

  @doc """
  Creates all processes related to a game, supervises them and puts that
  supervisor into the registry.
  """
  @spec create_game(
          size :: non_neg_integer(),
          mines :: non_neg_integer(),
          visibility :: Field.visibility()
        ) ::
          {:ok, String.t()} | {:error, any()}
  def create_game(size, mines, visibility) do
    game_id = generate_game_id()

    game_opts = %{
      size: size,
      mines: mines,
      game_id: game_id,
      visibility: visibility
    }

    name = {:via, Registry, {CoopMinesweeper.Game.GameRegistry, game_id}}

    case DynamicSupervisor.start_child(
           CoopMinesweeper.Game.GameSupervisor,
           {GameInstanceSupervisor, name: name, game_opts: game_opts}
         ) do
      {:ok, _pid} ->
        {:ok, game_id}

      # For now it is easier to just try to start the Supervisor With the game,
      # and catch the error that is returned by the Game process during
      # startup.
      {:error, {:shutdown, {:failed_to_start_child, Game, game_error}}} ->
        {:error, game_error}

      other_error ->
        other_error
    end
  end

  @doc """
  Returns the game process that is associated With the given game id.
  """
  @spec get_supervisor(game_id :: String.t()) :: {:ok, pid()} | not_found_error()
  def get_supervisor(game_id) do
    case Registry.lookup(CoopMinesweeper.Game.GameRegistry, game_id) do
      [] ->
        {:error, :not_found_error}

      [{supervisor, _}] ->
        {:ok, supervisor}
    end
  end

  @doc """
  Returns the game process that is associated With the given game id.
  """
  @spec get_game(game_id :: String.t()) :: {:ok, pid()} | not_found_error()
  def get_game(game_id) do
    with {:ok, game_instance_supervisor} <- get_supervisor(game_id) do
      {:ok, GameInstanceSupervisor.get_game(game_instance_supervisor)}
    end
  end

  @doc """
  Deletes a game process by its game id. This is done by killing its supervisor.
  """
  @spec delete(game_id :: String.t()) :: true | not_found_error()
  def delete(game_id) do
    with {:ok, game_instance_supervisor} <- get_supervisor(game_id) do
      Process.exit(game_instance_supervisor, :shutdown)
    end
  end

  @spec stream_game_pids() :: Stream.t()
  def stream_game_pids() do
    select_pid = [{{:_, :"$1", :_}, [], [:"$1"]}]

    CoopMinesweeper.Game.GameRegistry
    |> Registry.select(select_pid)
    |> Stream.map(&CoopMinesweeper.Game.GameInstanceSupervisor.get_game/1)
  end

  @spec generate_game_id() :: String.t()
  defp generate_game_id() do
    9_999_999_999
    |> :rand.uniform()
    |> to_string()
    |> String.pad_leading(10, "0")
  end
end

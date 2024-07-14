defmodule CoopMinesweeper.Game.GameRegistry do
  @moduledoc """
  This module is responsible for creating, saving and deleting supervised game
  agents.

  It makes sure that the game id is associated with its game agent and that the
  game agents are supervised so that they can't crash the application.
  """

  alias CoopMinesweeper.Game.{Game, Field}

  @type not_found_error() :: {:error, :not_found_error}

  @doc """
  Creates a new game agent, supervises it and puts it into the registry.
  """
  @spec create(
          size :: non_neg_integer(),
          mines :: non_neg_integer(),
          visibility :: Field.visibility()
        ) ::
          {:ok, {String.t(), pid()}} | {:error, any()}
  def create(size, mines, visibility) do
    game_id = generate_game_id()
    name = {:via, Registry, {CoopMinesweeper.GameRegistry, game_id}}

    game_opts = %{
      size: size,
      mines: mines,
      game_id: game_id,
      visibility: visibility
    }

    with {:ok, game_agent} <-
           DynamicSupervisor.start_child(
             CoopMinesweeper.GameSupervisor,
             {Game, name: name, game_opts: game_opts}
           ) do
      {:ok, {game_id, game_agent}}
    end
  end

  @doc """
  Returns a game agent that is associated the given game id.
  """
  @spec get(game_id :: String.t()) :: {:ok, pid()} | not_found_error()
  def get(game_id) do
    case Registry.lookup(CoopMinesweeper.GameRegistry, game_id) do
      [] -> {:error, :not_found_error}
      [{game_agent, _} | _] -> {:ok, game_agent}
    end
  end

  @doc """
  Deletes a game agent by its game id.
  """
  @spec delete(game_id :: String.t()) :: true | not_found_error()
  def delete(game_id) do
    with {:ok, game_agent} <- get(game_id) do
      # The Registry automatically deletes the PID and the DynamicSupervisor
      # can handle exits, so it is ok to just kill the game agent.
      Process.exit(game_agent, :kill)
    end
  end

  @spec list_game_pids() :: [pid()]
  def list_game_pids() do
    select_pid = [{{:_, :"$1", :_}, [], [:"$1"]}]
    Registry.select(CoopMinesweeper.GameRegistry, select_pid)
  end

  @spec generate_game_id() :: String.t()
  defp generate_game_id() do
    9_999_999_999
    |> :rand.uniform()
    |> to_string()
    |> String.pad_leading(10, "0")
  end
end

defmodule CoopMinesweeper.Game.Game do
  @moduledoc """
  This module holds the logic to interact with a minesweeper field. All calls
  to one field are done through its corresponding agent process so that no race
  conditions occur, when multiple players interact with the same field.
  """

  use Agent, restart: :temporary

  alias CoopMinesweeper.Game.Field

  @spec start_link(opts :: keyword()) :: Agent.on_start() | Field.on_new_error()
  def start_link(opts) do
    size = Keyword.fetch!(opts, :size)
    mines = Keyword.fetch!(opts, :mines)
    game_id = Keyword.fetch!(opts, :game_id)
    visibility = Keyword.fetch!(opts, :visibility)

    with {:ok, field} <- Field.new(size, mines, game_id, visibility) do
      Agent.start_link(fn -> field end, opts)
    end
  end

  @doc """
  Returns the underlying field of the game agent.
  """
  @spec get_field(game_agent :: pid()) :: Field.t()
  def get_field(game_agent) do
    Agent.get(game_agent, & &1)
  end

  @doc """
  Makes a turn in the game.
  """
  @spec make_turn(game_agent :: pid(), pos :: Field.position(), player :: String.t()) ::
          Field.on_make_turn()
  def make_turn(game_agent, pos, player) do
    Agent.get_and_update(
      game_agent,
      fn field ->
        case Field.make_turn(field, pos, player) do
          {:ok, {updated_field, _changes}} = ret -> {ret, updated_field}
          {:error, _} = err -> {err, field}
        end
      end,
      :timer.seconds(120)
    )
  end

  @doc """
  Toggles a mark in the game.
  """
  @spec toggle_mark(game_agent :: pid(), pos :: Field.position(), player :: String.t()) ::
          Field.on_toggle_mark()
  def toggle_mark(game_agent, pos, player) do
    Agent.get_and_update(
      game_agent,
      fn field ->
        case Field.toggle_mark(field, pos, player) do
          {:ok, {updated_field, _changes}} = ret -> {ret, updated_field}
          {:error, _} = err -> {err, field}
        end
      end,
      :timer.seconds(120)
    )
  end

  @doc """
  Restarts a game that is over.
  """
  @spec play_again(game_agent :: pid()) :: Field.on_play_again()
  def play_again(game_agent) do
    Agent.get_and_update(
      game_agent,
      fn field ->
        case Field.play_again(field) do
          {:ok, updated_field} = ret -> {ret, updated_field}
          {:error, _} = err -> {err, field}
        end
      end,
      :timer.seconds(120)
    )
  end
end

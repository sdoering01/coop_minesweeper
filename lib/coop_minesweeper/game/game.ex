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

    with {:ok, field} <- Field.new(size, mines, game_id) do
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
  @spec make_turn(game_agent :: pid(), pos :: Field.position()) :: Field.on_make_turn()
  def make_turn(game_agent, pos) do
    Agent.get_and_update(
      game_agent,
      fn field ->
        case Field.make_turn(field, pos) do
          {status, updated_field} = ret when status in [:ok, :won, :lost] ->
            {ret, updated_field}

          {:error, _} = err ->
            {err, field}
        end
      end,
      :timer.seconds(120)
    )
  end

  @doc """
  Toggles a mark in the game.
  """
  @spec toggle_mark(game_agent :: pid(), pos :: Field.position()) :: Field.on_toggle_mark()
  def toggle_mark(game_agent, pos) do
    Agent.get_and_update(
      game_agent,
      fn field ->
        case Field.toggle_mark(field, pos) do
          {:ok, updated_field} = ret -> {ret, updated_field}
          {:error, _} = err -> {err, field}
        end
      end,
      :timer.seconds(120)
    )
  end
end

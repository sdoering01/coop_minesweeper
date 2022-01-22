defmodule CoopMinesweeper.Game.Tile do
  @moduledoc """
  This module encapsulates the struct and some helper functions for the tiles
  of a minesweeper field.
  """

  alias __MODULE__

  defstruct mine?: false, state: :hidden, mines_close: 0

  @type state :: :hidden | :revealed | :mark | :mine | :false_mark

  @type t() :: %Tile{
          mine?: boolean(),
          state: state(),
          mines_close: non_neg_integer()
        }

  @spec set_state(tile :: Tile.t(), state :: state()) :: Tile.t()
  def set_state(%Tile{} = tile, state) do
    %{tile | state: state}
  end

  @spec change_to_mine(tile :: Tile.t()) :: Tile.t()
  def change_to_mine(%Tile{} = tile) do
    %{tile | mine?: true}
  end

  @spec increment_mines_close(tile :: Tile.t()) :: Tile.t()
  def increment_mines_close(%Tile{mines_close: mines_close} = tile) do
    %{tile | mines_close: mines_close + 1}
  end
end

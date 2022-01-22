defmodule CoopMinesweeper.Game.Field do
  @moduledoc """
  This module is responsible for the minesweeper fields. It initializes new
  fields and handles turns and mark toggles. It also determines whether a turn
  lead to a win or loss.
  """

  alias __MODULE__
  alias CoopMinesweeper.Game.Tile

  @min_size 6
  @max_size 20
  @min_mines 5

  # TODO: Track game state in struct
  # TODO: Don't allow make_mark until mines are initialized
  defstruct [:id, :size, :mines, :tiles, :mines_left, mines_initialized: false]

  @type position() :: {non_neg_integer(), non_neg_integer()}
  @type tiles() :: %{position() => Tile.t()}

  @type t() :: %Field{
          id: String.t(),
          size: non_neg_integer(),
          mines: non_neg_integer(),
          tiles: tiles(),
          mines_left: non_neg_integer(),
          mines_initialized: boolean()
        }

  @type on_new_error() :: {:error, :too_small | :too_large | :too_few_mines | :too_many_mines}

  @type on_make_turn() ::
          {:ok | :won | :lost, Field.t()} | {:error, :out_of_field | :invalid_position}

  @type on_toggle_mark() ::
          {:ok, Field.t()} | {:error, :out_of_field | :invalid_position}

  @doc """
  Generates a new field.
  """
  @spec new(size :: non_neg_integer(), mines :: non_neg_integer(), game_id :: String.t()) ::
          {:ok, Field.t()} | on_new_error()
  def new(size, _, _) when size < @min_size, do: {:error, :too_small}
  def new(size, _, _) when size > @max_size, do: {:error, :too_large}
  def new(_, mines, _) when mines < @min_mines, do: {:error, :too_few_mines}
  def new(size, mines, _) when mines > size * size / 4, do: {:error, :too_many_mines}

  def new(size, mines, game_id) when is_binary(game_id) do
    tiles =
      for row <- 0..(size - 1), col <- 0..(size - 1), into: %{} do
        {{row, col}, %Tile{}}
      end

    field = %Field{
      id: game_id,
      size: size,
      mines: mines,
      tiles: tiles,
      mines_left: mines
    }

    {:ok, field}
  end

  @doc """
  Makes a turn at the provided position of the field.

  If the field was untouched before, the mines are added before applying the
  turn. This ensures that the first turn isn't placed on a mine and reveals a
  bigger area.
  """
  @spec make_turn(field :: Field.t(), pos :: position()) :: on_make_turn()
  def make_turn(%Field{size: size}, {row, col})
      when row < 0 or row >= size or col < 0 or col >= size,
      do: {:error, :out_of_field}

  def make_turn(%Field{mines_initialized: false} = field, pos) do
    restricted_positions = get_surrounding_positions(field, pos)
    field = initialize_mines(field, restricted_positions)
    field = %{field | mines_initialized: true}

    make_turn(field, pos)
  end

  def make_turn(%Field{tiles: tiles} = field, pos) do
    cond do
      tiles[pos].state != :hidden ->
        {:error, :invalid_position}

      tiles[pos].mine? ->
        field = reveal_mines(field)
        {:lost, field}

      true ->
        field = reveal_tile(field, pos)

        if won?(field) do
          field =
            if field.mines_left > 0,
              do: reveal_mines(field),
              else: field

          {:won, field}
        else
          {:ok, field}
        end
    end
  end

  @doc """
  Marks a hidden tile or removes the mark of a marked tile.
  """
  @spec toggle_mark(field :: Field.t(), pos :: position()) :: on_toggle_mark()
  def toggle_mark(%Field{size: size}, {row, col})
      when row < 0 or row >= size or col < 0 or col >= size,
      do: {:error, :out_of_field}

  def toggle_mark(%Field{tiles: tiles} = field, pos) do
    case tiles[pos].state do
      :hidden ->
        field = update_in(field.tiles[pos], &Tile.set_state(&1, :mark))
        field = Map.update!(field, :mines_left, &(&1 - 1))
        {:ok, field}

      :mark ->
        field = update_in(field.tiles[pos], &Tile.set_state(&1, :hidden))
        field = Map.update!(field, :mines_left, &(&1 + 1))
        {:ok, field}

      _ ->
        {:error, :invalid_position}
    end
  end

  @doc """
  Determines whether a position is inside of the field.
  """
  @spec inside_field?(field :: Field.t(), pos :: position()) :: boolean()
  def inside_field?(%Field{size: size}, {row, col}) do
    row >= 0 and row < size and col >= 0 and col < size
  end

  @doc """
  Returns a list of positions that are around the provided position or the
  provided position itself. The returned positions are guaranteed to be
  inside of the field.
  """
  @spec get_surrounding_positions(field :: Field.t(), pos :: position(), include_self :: boolean) ::
          [position()]
  def get_surrounding_positions(%Field{} = field, {row, col}, include_self \\ true) do
    for restr_row <- (row - 1)..(row + 1),
        restr_col <- (col - 1)..(col + 1),
        inside_field?(field, {restr_row, restr_col}),
        include_self or restr_row != row or restr_col != col,
        do: {restr_row, restr_col}
  end

  @doc """
  Returns a string representation of the field.
  """
  @spec to_string(field :: Field.t()) :: String.t()
  def to_string(%Field{tiles: tiles, size: size}) do
    for row <- 0..(size - 1), into: "" do
      row_str =
        for col <- 0..(size - 1), tile = tiles[{row, col}], into: "" do
          if tile.mine?,
            do: "X",
            else: Kernel.to_string(tile.mines_close)
        end

      if row == size - 1 do
        row_str
      else
        row_str <> "\n"
      end
    end
  end

  @doc """
  Returns a string representation of the field that can be shown to the player.
  """
  @spec to_player_string(field :: Field.t()) :: String.t()
  def to_player_string(%Field{tiles: tiles, size: size}) do
    for row <- 0..(size - 1), into: "" do
      row_str =
        for col <- 0..(size - 1), tile = tiles[{row, col}], into: "" do
          case tile.state do
            :mine -> "X"
            :mark -> "M"
            :false_mark -> "F"
            :revealed -> Kernel.to_string(tile.mines_close)
            :hidden -> "_"
          end
        end

      if row == size - 1 do
        row_str
      else
        row_str <> "\n"
      end
    end
  end

  @spec initialize_mines(
          field :: Field.t(),
          restricted_positions :: [position()],
          mines_generated :: non_neg_integer()
        ) :: Field.t()
  defp initialize_mines(field, restricted_positions, mines_generated \\ 0)
  defp initialize_mines(%Field{mines: mines} = field, _, mines), do: field

  defp initialize_mines(
         %Field{} = field,
         restricted_positions,
         mines_generated
       ) do
    mine_position = generate_mine_position(field, restricted_positions)
    field = add_mine(field, mine_position)

    initialize_mines(field, restricted_positions, mines_generated + 1)
  end

  @spec generate_mine_position(field :: Field.t(), restricted_positions :: [position()]) ::
          position
  defp generate_mine_position(%Field{tiles: tiles, size: size} = field, restricted_positions) do
    pos = {:rand.uniform(size) - 1, :rand.uniform(size) - 1}

    if pos in restricted_positions or tiles[pos].mine? do
      generate_mine_position(field, restricted_positions)
    else
      pos
    end
  end

  @spec add_mine(field :: Field.t(), pos :: position()) :: Field.t()
  defp add_mine(%Field{} = field, pos) do
    field = update_in(field.tiles[pos], &Tile.change_to_mine/1)

    field
    |> get_surrounding_positions(pos, false)
    |> Enum.reduce(
      field,
      fn sur_pos, field ->
        update_in(field.tiles[sur_pos], &Tile.increment_mines_close/1)
      end
    )
  end

  # Reveals a tile which is not a mine. If the tile has zero mines close, also
  # reveal all surrounding tiles.
  @spec reveal_tile(field :: Field.t(), pos :: position()) :: Field.t()
  defp reveal_tile(%Field{} = field, pos) do
    if field.tiles[pos].state != :hidden do
      field
    else
      field = update_in(field.tiles[pos], &Tile.set_state(&1, :revealed))

      if field.tiles[pos].mines_close == 0 do
        field
        |> get_surrounding_positions(pos, false)
        |> Enum.reduce(field, fn sur_pos, field ->
          reveal_tile(field, sur_pos)
        end)
      else
        field
      end
    end
  end

  # Reveals mines and identifies false marks.
  @spec reveal_mines(field :: Field.t()) :: Field.t()
  defp reveal_mines(%Field{tiles: tiles} = field) do
    Enum.reduce(Map.keys(tiles), field, fn pos, field ->
      cond do
        field.tiles[pos].mine? and field.tiles[pos].state == :hidden ->
          update_in(field.tiles[pos], &Tile.set_state(&1, :mine))

        field.tiles[pos].state == :mark and not field.tiles[pos].mine? ->
          update_in(field.tiles[pos], &Tile.set_state(&1, :false_mark))

        true ->
          field
      end
    end)
  end

  @spec won?(field :: Field.t()) :: boolean()
  defp won?(%Field{tiles: tiles}) do
    Enum.all?(tiles, fn {_, tile} ->
      tile.state == :revealed or tile.mine?
    end)
  end
end

defimpl String.Chars, for: CoopMinesweeper.Game.Field do
  alias CoopMinesweeper.Game.Field

  def to_string(%Field{} = field) do
    Field.to_string(field)
  end
end
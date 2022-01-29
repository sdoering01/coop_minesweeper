defmodule CoopMinesweeper.Game.Field do
  @moduledoc """
  This module is responsible for the minesweeper fields. It initializes new
  fields and handles turns and mark toggles. It also determines whether a turn
  lead to a win or loss.
  """

  alias __MODULE__
  alias CoopMinesweeper.Game.Tile

  @min_size 6
  @max_size 50
  @min_mines 5

  defstruct [:id, :size, :mines, :tiles, :mines_left, :state, mines_initialized: false]

  @type position() :: {non_neg_integer(), non_neg_integer()}
  @type tiles() :: %{position() => Tile.t()}
  @type state() :: :running | :won | :lost

  @type t() :: %Field{
          id: String.t(),
          size: non_neg_integer(),
          mines: non_neg_integer(),
          tiles: tiles(),
          mines_left: non_neg_integer(),
          mines_initialized: boolean(),
          state: state()
        }

  @type on_new_error() :: {:error, :too_small | :too_large | :too_few_mines | :too_many_mines}

  @type on_make_turn() ::
          {:ok, {Field.t(), tiles()}} | {:error, :out_of_field | :invalid_position | :not_running}

  @type on_toggle_mark() ::
          {:ok, {Field.t(), tiles()}} | {:error, :out_of_field | :invalid_position | :not_running}

  @type on_play_again() ::
          {:ok, Field.t()} | {:error, :still_running}

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
      mines_left: mines,
      state: :running
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
  def make_turn(%Field{state: state}, _pos) when state != :running, do: {:error, :not_running}

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
        {field, changes} = reveal_mines(field, :lost)
        field = %{field | state: :lost}
        {:ok, {field, changes}}

      true ->
        {field, changes} = reveal_tile(field, pos)

        if won?(field) do
          {field, reveal_changes} = reveal_mines(field, :won)
          changes = Map.merge(changes, reveal_changes)
          field = %{field | mines_left: 0}
          field = %{field | state: :won}
          {:ok, {field, changes}}
        else
          {:ok, {field, changes}}
        end
    end
  end

  @doc """
  Marks a hidden tile or removes the mark of a marked tile.
  """
  @spec toggle_mark(field :: Field.t(), pos :: position()) :: on_toggle_mark()
  def toggle_mark(%Field{state: state}, _pos) when state != :running, do: {:error, :not_running}

  def toggle_mark(%Field{mines_initialized: mines_initialized}, _pos) when not mines_initialized,
    do: {:error, :mines_not_initialized}

  def toggle_mark(%Field{size: size}, {row, col})
      when row < 0 or row >= size or col < 0 or col >= size,
      do: {:error, :out_of_field}

  def toggle_mark(%Field{tiles: tiles} = field, pos) do
    case tiles[pos].state do
      :hidden ->
        field = update_in(field.tiles[pos], &Tile.set_state(&1, :mark))
        field = Map.update!(field, :mines_left, &(&1 - 1))
        {:ok, {field, %{pos => field.tiles[pos]}}}

      :mark ->
        field = update_in(field.tiles[pos], &Tile.set_state(&1, :hidden))
        field = Map.update!(field, :mines_left, &(&1 + 1))
        {:ok, {field, %{pos => field.tiles[pos]}}}

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
  Resets a field that is not running.
  """
  @spec play_again(field :: Field.t()) :: on_play_again()
  def play_again(%Field{state: :running}), do: {:error, :still_running}

  def play_again(%Field{id: id, size: size, mines: mines}) do
    {:ok, field} = new(size, mines, id)
    {:ok, field}
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
  @spec reveal_tile(
          field :: Field.t(),
          pos :: position(),
          changes_so_far :: tiles()
        ) :: {Field.t(), tiles()}
  defp reveal_tile(%Field{} = field, pos, changes_so_far \\ %{}) do
    if field.tiles[pos].state != :hidden do
      {field, changes_so_far}
    else
      field = update_in(field.tiles[pos], &Tile.set_state(&1, :revealed))
      changes_so_far = Map.put(changes_so_far, pos, field.tiles[pos])

      if field.tiles[pos].mines_close == 0 do
        field
        |> get_surrounding_positions(pos, false)
        |> Enum.reduce({field, changes_so_far}, fn sur_pos, {field, changes_so_far} ->
          reveal_tile(field, sur_pos, changes_so_far)
        end)
      else
        {field, changes_so_far}
      end
    end
  end

  # Reveals mines and identifies false marks.
  @spec reveal_mines(field :: Field.t(), mode :: :won | :lost) :: {Field.t(), tiles()}
  defp reveal_mines(%Field{mines_left: 0} = field, _mode), do: {field, %{}}

  defp reveal_mines(%Field{tiles: tiles} = field, mode) do
    hidden_substitution = if mode == :won, do: :mark, else: :mine

    Enum.reduce(Map.keys(tiles), {field, %{}}, fn pos, {field, changes_so_far} ->
      cond do
        field.tiles[pos].mine? and field.tiles[pos].state == :hidden ->
          field = update_in(field.tiles[pos], &Tile.set_state(&1, hidden_substitution))
          {field, Map.put(changes_so_far, pos, field.tiles[pos])}

        field.tiles[pos].state == :mark and not field.tiles[pos].mine? ->
          field = update_in(field.tiles[pos], &Tile.set_state(&1, :false_mark))
          {field, Map.put(changes_so_far, pos, field.tiles[pos])}

        true ->
          {field, changes_so_far}
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

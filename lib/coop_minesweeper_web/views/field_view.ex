defmodule CoopMinesweeperWeb.FieldView do
  use CoopMinesweeperWeb, :view

  alias CoopMinesweeper.Game.{Tile, Field}

  def render("player_field.json", %{
        field:
          %Field{
            tiles: tiles,
            size: size
          } = field
      }) do
    Map.merge(
      %{
        tiles:
          for row <- 0..(size - 1) do
            for col <- 0..(size - 1) do
              render("tile.json", tile: tiles[{row, col}])
            end
          end
      },
      render("field_metadata.json", field: field)
    )
  end

  def render("field_changes.json", %{
        field: %Field{mines_left: mines_left, state: state, recent_player: recent_player},
        changes: changes
      }) do
    %{
      changes:
        for {{row, col}, tile} <- changes do
          [[row, col], render("tile.json", tile: tile)]
        end,
      field: %{
        mines_left: mines_left,
        state: state,
        recent_player: recent_player
      }
    }
  end

  def render("field_metadata.json", %{
        field: %Field{
          size: size,
          mines: mines,
          mines_left: mines_left,
          state: state,
          recent_player: recent_player
        }
      }) do
    %{
      size: size,
      mines: mines,
      mines_left: mines_left,
      state: state,
      recent_player: recent_player
    }
  end

  def render("tile.json", %{tile: %Tile{state: :revealed, mines_close: mines_close}}) do
    %{state: :revealed, mines_close: mines_close}
  end

  def render("tile.json", %{tile: %Tile{state: state}}) do
    %{state: state}
  end
end

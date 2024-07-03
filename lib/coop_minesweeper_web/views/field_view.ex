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
        field: %Field{
          mines_left: mines_left,
          state: state,
          recent_player: recent_player,
          started_at: started_at,
          finished_at: finished_at
        },
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
        started_at: started_at,
        finished_at: finished_at,
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
          started_at: started_at,
          finished_at: finished_at,
          recent_player: recent_player
        }
      }) do
    %{
      size: size,
      mines: mines,
      mines_left: mines_left,
      state: state,
      started_at: started_at,
      finished_at: finished_at,
      recent_player: recent_player
    }
  end

  def render("field_list.json", %{
        field_list: field_list
      }) do
    render_many(field_list, CoopMinesweeperWeb.FieldView, "field_list_entry.json",
      as: :list_entry
    )
  end

  def render("field_list_entry.json", %{
        list_entry: %{
          field: %Field{
            id: id,
            size: size,
            mines: mines,
            mines_left: mines_left
          },
          player_count: player_count
        }
      }) do
    %{
      id: id,
      size: size,
      mines: mines,
      mines_left: mines_left,
      player_count: player_count
    }
  end

  def render("tile.json", %{tile: %Tile{state: :revealed, mines_close: mines_close}}) do
    %{state: :revealed, mines_close: mines_close}
  end

  def render("tile.json", %{tile: %Tile{state: state}}) do
    %{state: state}
  end
end

defmodule CoopMinesweeperWeb.GameController do
  use CoopMinesweeperWeb, :controller
  alias CoopMinesweeper.Game.{GameRegistry, Game}

  def info(conn, %{"game_id" => game_id}) do
    with {:ok, game} <- GameRegistry.get(game_id), field <- Game.get_field(game) do
      conn
      |> put_view(CoopMinesweeperWeb.FieldView)
      |> render("field_metadata.json", field: field)
    else
      {:error, :not_found_error} ->
        conn
        |> put_status(:not_found)
        |> json(%{})
    end
  end

  def index(conn, _params) do
    field_list = CoopMinesweeper.Game.list_public_fields()

    conn
    |> put_view(CoopMinesweeperWeb.FieldView)
    |> render("field_list.json", field_list: field_list)
  end
end

defmodule CoopMinesweeperWeb.PageController do
  use CoopMinesweeperWeb, :controller

  def index(conn, _params) do
    render(conn, "index.html")
  end
end

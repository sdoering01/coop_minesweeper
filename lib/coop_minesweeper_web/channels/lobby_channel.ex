defmodule CoopMinesweeperWeb.LobbyChannel do
  use Phoenix.Channel
  alias CoopMinesweeper.Game.GameRegistry
  require Logger

  def join("lobby", _params, socket) do
    {:ok, socket}
  end

  def handle_in("create_game", _params, socket) do
    case GameRegistry.create(20, 20) do
      {:ok, {game_id, _}} ->
        {:reply, {:ok, %{game_id: game_id}}, socket}

      ret ->
        Logger.error("Error when creating game: " <> inspect(ret))
        {:reply, :error, socket}
    end
  end

  # Fallback to not crash socket process
  def handle_in(event, _params, socket) do
    {:reply, {:error, %{reason: "unexpected_event", event: event}}, socket}
  end
end

defmodule CoopMinesweeperWeb.LobbyChannel do
  use Phoenix.Channel
  alias CoopMinesweeper.Game.GameRegistry
  require Logger

  def join("lobby", _params, socket) do
    {:ok, socket}
  end

  def handle_in("create_game", %{"size" => size, "mines" => mines}, socket)
      when is_number(size) and is_number(mines) do
    case GameRegistry.create(size, mines) do
      {:ok, {game_id, _}} ->
        {:reply, {:ok, %{game_id: game_id}}, socket}

      {:error, reason} ->
        Logger.error("Error when creating game: " <> inspect(reason))
        message = translate_create_game_error(reason)
        {:reply, {:error, %{reason: reason, message: message}}, socket}
    end
  end

  # Fallback to not crash socket process
  def handle_in(event, _params, socket) do
    {:reply, {:error, %{reason: "unexpected_event", event: event}}, socket}
  end

  defp translate_create_game_error(:too_large), do: "Field is too large"
  defp translate_create_game_error(:too_small), do: "Field is too small"
  defp translate_create_game_error(:too_many_mines), do: "Field has many mines"
  defp translate_create_game_error(:too_few_mines), do: "Field has too few mines"
  defp translate_create_game_error(_reason), do: "An unexpected error occurred"
end

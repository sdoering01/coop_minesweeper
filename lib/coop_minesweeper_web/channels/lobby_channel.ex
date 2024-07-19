defmodule CoopMinesweeperWeb.LobbyChannel do
  use Phoenix.Channel
  alias CoopMinesweeper.Game.GameRegistry
  require Logger

  def join("lobby", _params, socket) do
    {:ok, socket}
  end

  def handle_in(
        "create_game",
        %{"size" => size, "mines" => mines, "visibility" => visibility},
        socket
      )
      when is_number(size) and is_number(mines) and visibility in ~w[public private] do
    case GameRegistry.create_game(size, mines, String.to_existing_atom(visibility)) do
      {:ok, game_id} ->
        {:reply, {:ok, %{game_id: game_id}}, socket}

      {:error, reason} ->
        Logger.error("Error when creating game: " <> inspect(reason))
        message = translate_create_game_error(reason)
        response = {:error, %{reason: inspect(reason), message: message}}
        {:reply, response, socket}
    end
  end

  # Fallback to not crash socket process
  def handle_in(event, params, socket) do
    Logger.info(message: "Unexpected event", event: event, params: params)
    {:reply, {:error, %{reason: "unexpected_event", event: event}}, socket}
  end

  defp translate_create_game_error(:too_large), do: "Field is too large"
  defp translate_create_game_error(:too_small), do: "Field is too small"
  defp translate_create_game_error(:too_many_mines), do: "Field has many mines"
  defp translate_create_game_error(:too_few_mines), do: "Field has too few mines"
  defp translate_create_game_error(_reason), do: "An unexpected error occurred"
end

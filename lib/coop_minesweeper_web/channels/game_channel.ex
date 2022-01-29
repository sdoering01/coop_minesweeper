defmodule CoopMinesweeperWeb.GameChannel do
  use Phoenix.Channel
  alias Phoenix.Socket
  require Logger
  alias CoopMinesweeper.Game.{GameRegistry, Game, Field}
  alias CoopMinesweeperWeb.FieldView

  def join("game:" <> game_id, _message, socket) do
    case GameRegistry.get(game_id) do
      {:ok, game} ->
        field_json = FieldView.render("player_field.json", field: Game.get_field(game))
        socket = assign(socket, game: game)
        {:ok, %{field: field_json}, socket}

      {:error, :not_found_error} ->
        {:error, %{reason: "does_not_exist"}}
    end
  end

  def handle_in("tile:reveal", %{"row" => row, "col" => col}, socket)
      when is_integer(row) and is_integer(col) do
    case Game.make_turn(socket.assigns.game, {row, col}) do
      {:ok, {new_field, changes}} ->
        # broadcast_field(socket, new_field)
        broadcast_changes(socket, new_field, changes)
        {:noreply, socket}

      {:error, reason} ->
        {:reply, {:error, %{reason: reason}}, socket}
    end
  end

  def handle_in("tile:toggle", %{"row" => row, "col" => col}, socket)
      when is_integer(row) and is_integer(col) do
    case Game.toggle_mark(socket.assigns.game, {row, col}) do
      {:ok, {new_field, changes}} ->
        # broadcast_field(socket, new_field)
        broadcast_changes(socket, new_field, changes)
        {:noreply, socket}

      {:error, reason} ->
        {:reply, {:error, %{reason: reason}}, socket}
    end
  end

  def handle_in("game:play_again", _params, socket) do
    case Game.play_again(socket.assigns.game) do
      {:ok, new_field} ->
        field_metadata = FieldView.render("field_metadata.json", field: new_field)
        broadcast(socket, "game:play_again", %{field: field_metadata})
        {:noreply, socket}

      {:error, reason} ->
        {:reply, {:error, %{reason: reason}}, socket}
    end
  end

  # Fallback to not crash socket process
  def handle_in(event, _params, socket) do
    {:reply, {:error, %{reason: "unexpected_event", event: event}}, socket}
  end

  # @spec broadcast_field(socket :: Socket.t(), new_field :: Field.t()) :: any
  # defp broadcast_field(socket, new_field) do
  #   field_json = FieldView.render("player_field.json", field: new_field)
  #   broadcast(socket, "field:update", %{field: field_json})
  # end

  @spec broadcast_changes(socket :: Socket.t(), field :: Field.t(), changes :: Field.tiles()) ::
          any
  defp broadcast_changes(socket, field, changes) do
    response = FieldView.render("field_changes.json", field: field, changes: changes)
    broadcast(socket, "field:changes", response)
  end
end

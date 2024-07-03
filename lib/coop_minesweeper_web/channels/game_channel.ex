defmodule CoopMinesweeperWeb.GameChannel do
  use Phoenix.Channel
  alias Phoenix.Socket
  require Logger
  alias CoopMinesweeper.Game.{GameRegistry, Game, Field}
  alias CoopMinesweeperWeb.FieldView
  alias CoopMinesweeperWeb.Presence

  @default_name "Anonymous"

  def join("game:" <> game_id, _params, socket) do
    case GameRegistry.get(game_id) do
      {:ok, game} ->
        field_json = FieldView.render("player_field.json", field: Game.get_field(game))
        user_id = :rand.uniform(1_000_000_000)

        socket =
          socket
          |> assign(:game, game)
          |> assign(:user_id, user_id)
          |> assign(:joined, false)

        send(self(), :after_join)

        {:ok, %{field: field_json}, socket}

      {:error, :not_found_error} ->
        {:error, %{reason: "does_not_exist"}}
    end
  end

  def handle_info(:after_join, socket) do
    {:ok, _} =
      Presence.track(socket, socket.assigns.user_id, %{
        name: @default_name,
        joined: false
      })

    push(socket, "presence_state", Presence.list(socket))
    {:noreply, socket}
  end

  def handle_info(:after_game_join, socket) do
    {:ok, _} =
      Presence.update(socket, socket.assigns.user_id, %{
        name: socket.assigns.name,
        joined: true
      })

    {:noreply, socket}
  end

  def handle_in("game:join", %{"name" => name}, socket) do
    name = String.trim(name)
    name = if String.length(name) > 0, do: name, else: @default_name

    socket =
      socket
      |> assign(:name, name)
      |> assign(:joined, true)

    send(self(), :after_game_join)
    {:reply, :ok, socket}
  end

  def handle_in(_event, _params, %{assigns: %{joined: false}} = socket) do
    {:reply, {:error, %{reason: :not_joined}}, socket}
  end

  ## Only for joined players

  def handle_in("tile:reveal", %{"row" => row, "col" => col}, socket)
      when is_integer(row) and is_integer(col) do
    case Game.make_turn(socket.assigns.game, {row, col}, socket.assigns.name) do
      {:ok, {new_field, changes}} ->
        broadcast_changes(socket, new_field, changes)
        {:noreply, socket}

      {:error, reason} ->
        {:reply, {:error, %{reason: reason}}, socket}
    end
  end

  def handle_in("tile:toggle", %{"row" => row, "col" => col}, socket)
      when is_integer(row) and is_integer(col) do
    case Game.toggle_mark(socket.assigns.game, {row, col}, socket.assigns.name) do
      {:ok, {new_field, changes}} ->
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
  def handle_in(event, params, socket) do
    Logger.info(message: "Unexpected event", event: event, params: params)
    {:reply, {:error, %{reason: "unexpected_event", event: event}}, socket}
  end

  @spec broadcast_changes(socket :: Socket.t(), field :: Field.t(), changes :: Field.tiles()) ::
          any
  defp broadcast_changes(socket, field, changes) do
    response = FieldView.render("field_changes.json", field: field, changes: changes)
    broadcast(socket, "field:changes", response)
  end
end

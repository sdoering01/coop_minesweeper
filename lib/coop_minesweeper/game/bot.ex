defmodule CoopMinesweeper.Game.Bot do
  use GenServer, restart: :transient

  alias CoopMinesweeper.Game.{GameRegistry, Game, Field, Tile}

  @time_between_turns :timer.seconds(2)

  def start_link(opts) do
    game_id = Keyword.fetch!(opts, :game_id)

    GenServer.start_link(__MODULE__, game_id, opts)
  end

  def init(game_id) do
    {:ok, game} = GameRegistry.get_game(game_id)
    field = Game.get_field(game)

    topic = "game:" <> game_id
    name = "Mineseeker"
    Phoenix.PubSub.subscribe(CoopMinesweeper.PubSub, topic)
    track_presence(topic, name)

    schedule_turn()

    state = %{name: name, game: game, field: field, turn_pos: {0, 0}}
    {:ok, state}
  end

  def handle_info(:make_turn, state) do
    state =
      if state.field.state == :running do
        {action, turn_pos} = find_next_pos(state.turn_pos, state.field)

        case action do
          :turn -> Game.make_turn(state.game, turn_pos, state.name)
          :mark -> Game.toggle_mark(state.game, turn_pos, state.name)
        end

        %{state | turn_pos: turn_pos}
      else
        state
      end

    schedule_turn()

    {:noreply, state}
  end

  def handle_info({:field_changes, {new_field_without_tiles, changes}}, state) do
    new_field =
      if !state.field.mines_initialized and new_field_without_tiles.mines_initialized do
        # Mines were initialized, so get the field with the correct mine tiles
        Game.get_field(state.game)
      else
        field_with_updated_tiles = Field.apply_tile_changes(state.field, changes)
        %{new_field_without_tiles | tiles: field_with_updated_tiles.tiles}
      end

    state = %{state | field: new_field}
    {:noreply, state}
  end

  def handle_info({:play_again, new_field}, state) do
    state = %{state | field: new_field, turn_pos: {0, 0}}
    {:noreply, state}
  end

  # Ignore broadcasts for sockets
  def handle_info(%Phoenix.Socket.Broadcast{}, state) do
    {:noreply, state}
  end

  defp advance_pos({row, col}, size) when row >= size - 1 and col >= size - 1, do: {0, 0}
  defp advance_pos({row, col}, size) when col >= size - 1, do: {row + 1, 0}
  defp advance_pos({row, col}, _size), do: {row, col + 1}

  defp find_next_pos(pos, field) do
    case field.tiles[pos] do
      %Tile{state: :hidden, mine?: false} -> {:turn, pos}
      %Tile{state: :hidden, mine?: true} -> {:mark, pos}
      %Tile{} -> pos |> advance_pos(field.size) |> find_next_pos(field)
    end
  end

  defp schedule_turn() do
    Process.send_after(self(), :make_turn, @time_between_turns)
  end

  defp track_presence(topic, name) do
    random_key = "bot:#{:rand.uniform(1_000_000_000)}"

    CoopMinesweeperWeb.Presence.track(self(), topic, random_key, %{
      name: name,
      joined: true,
      bot?: true
    })
  end
end

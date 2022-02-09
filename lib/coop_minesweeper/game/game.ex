defmodule CoopMinesweeper.Game.Game do
  @moduledoc """
  This module holds the logic to interact with a minesweeper field. All calls
  to one field are done through its corresponding process so that no race
  conditions occur, when multiple players interact with the same field.
  """

  use GenServer, restart: :temporary

  alias CoopMinesweeper.Game.Field
  require Logger

  @idle_time 5 * 60 * 1000

  ## Client API

  @doc """
  Starts a new game.
  """
  @spec start_link(opts :: keyword()) :: GenServer.on_start() | Field.on_new_error()
  def start_link(opts) do
    size = Keyword.fetch!(opts, :size)
    mines = Keyword.fetch!(opts, :mines)
    game_id = Keyword.fetch!(opts, :game_id)
    visibility = Keyword.fetch!(opts, :visibility)

    with {:ok, field} <- Field.new(size, mines, game_id, visibility) do
      GenServer.start_link(__MODULE__, field, opts)
    end
  end

  @doc """
  Returns the underlying field of the game.
  """
  @spec get_field(game :: pid()) :: Field.t()
  def get_field(game) do
    GenServer.call(game, :get_field)
  end

  @doc """
  Makes a turn in the game.
  """
  @spec make_turn(game :: pid(), pos :: Field.position(), player :: String.t()) ::
          Field.on_make_turn()
  def make_turn(game, pos, player) do
    GenServer.call(game, {:make_turn, pos, player})
  end

  @doc """
  Toggles a mark in the game.
  """
  @spec toggle_mark(game :: pid(), pos :: Field.position(), player :: String.t()) ::
          Field.on_toggle_mark()
  def toggle_mark(game, pos, player) do
    GenServer.call(game, {:toggle_mark, pos, player})
  end

  @doc """
  Restarts a game that is over.
  """
  @spec play_again(game :: pid()) :: Field.on_play_again()
  def play_again(game) do
    GenServer.call(game, :play_again)
  end

  ## Server API

  @impl true
  def init(state) do
    Process.send_after(self(), :maybe_cleanup, @idle_time)
    {:ok, state}
  end

  @impl true
  def handle_info(:maybe_cleanup, %Field{id: id, last_interaction: last_interaction} = field) do
    now = DateTime.utc_now()
    cleanup_time = DateTime.add(last_interaction, @idle_time, :millisecond)
    diff = DateTime.diff(cleanup_time, now, :millisecond)

    if diff <= 0 do
      if CoopMinesweeper.Game.get_game_player_count(id) > 0 do
        Process.send_after(self(), :maybe_cleanup, @idle_time)
        {:noreply, field}
      else
        Logger.info("Cleaning up game #{id}")
        {:stop, :shutdown, field}
      end
    else
      Process.send_after(self(), :maybe_cleanup, diff)
      {:noreply, field}
    end
  end

  @impl true
  def handle_call(:get_field, _from, field) do
    {:reply, field, field}
  end

  @impl true
  def handle_call({:make_turn, pos, player}, _from, field) do
    case Field.make_turn(field, pos, player) do
      {:ok, {updated_field, _changes}} = ret -> {:reply, ret, updated_field}
      {:error, _} = err -> {:reply, err, field}
    end
  end

  @impl true
  def handle_call({:toggle_mark, pos, player}, _from, field) do
    case Field.toggle_mark(field, pos, player) do
      {:ok, {updated_field, _changes}} = ret -> {:reply, ret, updated_field}
      {:error, _} = err -> {:reply, err, field}
    end
  end

  @impl true
  def handle_call(:play_again, _from, field) do
    case Field.play_again(field) do
      {:ok, updated_field} = ret -> {:reply, ret, updated_field}
      {:error, _} = err -> {:reply, err, field}
    end
  end
end

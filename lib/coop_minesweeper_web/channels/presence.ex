defmodule CoopMinesweeperWeb.Presence do
  @moduledoc """
  Provides presence tracking to channels and processes.

  See the [`Phoenix.Presence`](https://hexdocs.pm/phoenix/Phoenix.Presence.html)
  docs for more details.
  """
  use Phoenix.Presence,
    otp_app: :coop_minesweeper,
    pubsub_server: CoopMinesweeper.PubSub
end

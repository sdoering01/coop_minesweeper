defmodule CoopMinesweeper.Repo do
  use Ecto.Repo,
    otp_app: :coop_minesweeper,
    adapter: Ecto.Adapters.Postgres
end

# CoopMinesweeper

This project is a multiplayer remake of the classic game Minesweeper.

## Development

The server uses Elixir with the Phoenix framework. The web client uses the
Svelte framework.

To get started install the Elixir toolchain (Erlang, Elixir and mix) and the
Javascript toolchain (node and npm).

To start the Phoenix server:

  * Install dependencies with `mix deps.get`
  * Create and migrate your database with `mix ecto.setup`
  * Start Phoenix endpoint with `mix phx.server` or inside IEx with `iex -S mix phx.server`

To start the web client:

  * Change into `web` directory
  * Install dependencies with `npm install`
  * Start the development server with `npm run dev`


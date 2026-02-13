defmodule CoopMinesweeper.Game.BotSupervisor do
  use DynamicSupervisor

  def start_link(init_arg) do
    DynamicSupervisor.start_link(__MODULE__, init_arg)
  end

  def init(_init_arg) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end

  def count_bots(supervisor) do
    DynamicSupervisor.count_children(supervisor).active
  end
end

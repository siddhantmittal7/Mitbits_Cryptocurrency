defmodule Chord.NodeSupervisor do
  use DynamicSupervisor
  @me NodeSupervisor
  def start_link(_) do
    DynamicSupervisor.start_link(__MODULE__, :no_args, name: @me)
  end

  def init(:no_args) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end

  def add_node(node_id, m) do
    {:ok, _pid} = DynamicSupervisor.start_child(@me, {Chord.Node, {node_id, m}})
    _pid
  end
end

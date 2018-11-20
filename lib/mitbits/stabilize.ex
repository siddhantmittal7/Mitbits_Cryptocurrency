defmodule Chord.Stabilize do
  use GenServer
  @me __MODULE__

  # API
  def start_link(_) do
    GenServer.start_link(__MODULE__, :no_args, name: @me)
  end

  def start_stabilize() do
    GenServer.cast(@me, :stabilize)
  end

  # SERVER
  def init(:no_args) do
    {:ok, 0}
  end

  def handle_cast(:stabilize, state) do
    node_supervisor_id = Process.whereis(NodeSupervisor)
    data = DynamicSupervisor.which_children(node_supervisor_id)

    added_nodes =
      Enum.map(data, fn {_, pid, _, _} ->
        pid
      end)

    Enum.each(added_nodes, fn x ->
      GenServer.cast(x, :stabilize)
      Process.sleep(1)
    end)

    Enum.each(added_nodes, fn x ->
      GenServer.cast(x, :fix_fingers)
      Process.sleep(1)
    end)

    GenServer.cast(@me, :stabilize)
    {:noreply, state}
  end
end

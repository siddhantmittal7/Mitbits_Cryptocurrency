defmodule Mitbits.Driver do
  use GenServer
  import Mitbits.RSA
  @me __MODULE__

  # API
  def start_link(_) do
    GenServer.start_link(__MODULE__, :no_args, name: @me)
  end

  # SERVER
  def init(:no_args) do
    Process.send_after(self(), :kickoff, 0)
    {:ok, {}}
  end

  def handle_info(:kickoff, {}) do
    numNodes = 20
    numMiners = 5
    IO.puts "here"
    node_pks =
      Enum.map(1..numNodes, fn node ->
        {:ok, {sk, pk}} = RsaEx.generate_keypair()
        # IO.inspect([pk, sk])
        # IO.inspect MapSet.size(set)
        {:ok, pid} = Mitbits.NodeSupervisor.add_node(pk, sk)
        # IO.inspect(pid)
        {pk, pid}
      end)

    # IO.inspect node_pks

    # IO.inspect Enum.count(node_pks)
    # IO.inspect(node_pks)

    miner_pks =
      Enum.map(1..numMiners, fn miner ->
        {:ok, {sk, pk}} = RsaEx.generate_keypair()
        # IO.inspect pk
        # IO.inspect sk
        # IO.inspect(pk, sk)
        {:ok, pid} = Mitbits.MinerSupervisor.add_miner(pk, sk)
        {pk, pid}
      end)

    :ets.new(:mitbits, [:set, :public, :named_table])
    :ets.insert(:mitbits, {"unchained_txn", []})

    [{first_miner_pk, first_miner_pid} | _] = miner_pks
     IO.puts("rgd")
    GenServer.cast(first_miner_pid, {:mine_first, "the fox jkfsndaljd"})
    {:noreply, {}}
  end

  defp fill_map(node_set, numNodes, max) do
    if(MapSet.size(node_set) >= numNodes) do
      node_set
    else
      rand_node_id = Enum.random(1..max)
      node_set = MapSet.put(node_set, rand_node_id)
      fill_map(node_set, numNodes, max)
    end
  end
end

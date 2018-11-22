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

    node_pks =
      Enum.map(1..numNodes, fn node ->
        {:ok, {sk, pk}} = RsaEx.generate_keypair
        IO.inspect [pk,sk]
        {:ok, _} = Mitbits.NodeSupervisor.add_node(pk, sk)
        pk
      end)

    IO.inspect(node_pks)

    miner_pks =
      Enum.map(1..numMiners, fn miner ->
        {pk, sk} = Mitbits.RSA.getKeypair()
        _ = Mitbits.MinerSupervisor.add_miner(pk, sk)
        pk
      end)

    :ets.new(:mitbits_unchained_txn, [:set, :public, :named_table])
    :ets.insert(:mitbits, {"unchained_txn", []})

    [first | _] = miner_pks
    IO.puts("rgd")
    GenServer.call(:"miner_#{first}", {:mine_first, "the fox jkfsndaljd"})
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

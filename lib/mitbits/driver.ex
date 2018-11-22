defmodule Mitbits.Driver do
  use GenServer
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

    miners = Map.new()
    nodes = Map.new()

    miner_pk_pid_sk =
      Enum.map(1..numMiners, fn _ ->
        {:ok, {sk, pk}} = RsaEx.generate_keypair()
        {:ok, pid} = Mitbits.MinerSupervisor.add_miner(pk, sk)
        {pk, pid, sk}
      end)

    miner =
      Enum.reduce(miner_pk_pid_sk, %{}, fn {pk, pid, sk}, miner ->
        Map.put_new(miner, String.to_atom(pk), {pid, sk})
      end)

    :ets.new(:mitbits, [:set, :public, :named_table])
    :ets.insert(:mitbits, {"unchained_txn", []})
    :ets.insert(:mitbits, {"miner", miner})

    [{first_miner_pk, first_miner_pid, _} | _] = miner_pk_pid_sk
    {genesis_block} = GenServer.call(first_miner_pid, {:mine_first, "the fox jkfsndaljd"})

    IO.inspect(genesis_block)

    miner_node_pk_pid =
      Enum.map(miner_pk_pid_sk, fn {pk, _, sk} ->
        {:ok, pid} = Mitbits.NodeSupervisor.add_node(pk, sk, genesis_block)
        {:ok} = GenServer.call(pid, :update_wallet)
        {pk, pid}
      end)

    nodes =
      Enum.reduce(miner_node_pk_pid, %{}, fn {pk, pid}, nodes ->
        Map.put_new(nodes, String.to_atom(pk), pid)
      end)

    :ets.insert(:mitbits, {"nodes", nodes})

    node_pk_pid =
      Enum.map(1..numNodes, fn _ ->
        {:ok, {sk, pk}} = RsaEx.generate_keypair()
        {:ok, pid} = Mitbits.NodeSupervisor.add_node(pk, sk, genesis_block)
        {:ok} = GenServer.call(pid, :update_wallet)
        key = String.to_atom(first_miner_pk)
        {:ok} = GenServer.call(pid, {:buy_bitcoins, nodes.key})
        {pk, pid}
      end)

    nodes =
      Enum.reduce(node_pk_pid, %{}, fn {pk, pid}, nodes ->
        Map.put_new(nodes, String.to_atom(pk), pid)
      end)

    :ets.insert(:mitbits, {"nodes", nodes})

    Mitbits.Utility.print_txns()

    {:noreply, {}}
  end
end
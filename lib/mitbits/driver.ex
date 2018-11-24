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

    miner_pk_hash_sk =
      Enum.map(1..numMiners, fn _ ->
        {:ok, {sk, pk}} = RsaEx.generate_keypair()
        hash_name = Mitbits.Utility.getHash(pk)
        {:ok, _} = Mitbits.MinerSupervisor.add_miner(pk, sk, hash_name)
        {pk, hash_name, sk}
      end)

    :ets.new(:mitbits, [:set, :public, :named_table])
    :ets.insert(:mitbits, {"unchained_txn", []})

    [{first_miner_pk, first_miner_hash, _} | _] = miner_pk_hash_sk

    {genesis_block} =
      GenServer.call(
        Mitbits.Utility.string_to_atom("miner_" <> first_miner_hash),
        {:mine_first, "the fox jkfsndaljd"}
      )

    # IO.inspect(genesis_block)

    miner_node_hash =
      Enum.map(miner_pk_hash_sk, fn {pk, hash_name, sk} ->
        {:ok, _} = Mitbits.NodeSupervisor.add_node(pk, sk, genesis_block, hash_name)

        {:ok} =
          GenServer.call(Mitbits.Utility.string_to_atom("node_" <> hash_name), :update_wallet)

        {hash_name}
      end)

    # Enum.each(miner_node_hash, fn {hash} ->
    #   IO.inspect(Mitbits.Node.get_balance(hash))
    # end)

    node_hash =
      Enum.map(1..numNodes, fn _ ->
        {:ok, {sk, pk}} = RsaEx.generate_keypair()
        hash_name = Mitbits.Utility.getHash(pk)
        {:ok, _} = Mitbits.NodeSupervisor.add_node(pk, sk, genesis_block, hash_name)

        {:ok} =
          GenServer.call(Mitbits.Utility.string_to_atom("node_" <> hash_name), :update_wallet)

        {:ok} =
          GenServer.call(
            Mitbits.Utility.string_to_atom("node_" <> hash_name),
            {:buy_bitcoins, first_miner_hash}
          )

        {hash_name}
      end)

    all_nodes = miner_node_hash ++ node_hash
    :ets.insert(:mitbits, {"nodes", all_nodes})

    # Mitbits.Utility.print_txns()

    Mitbits.Miner.start_mining(first_miner_hash)

    {:noreply, {}}
  end
end

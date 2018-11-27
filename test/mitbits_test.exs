defmodule MitbitsTest do
  use ExUnit.Case

  doctest Mitbits.Application

  setup_all do
    children = [
      Mitbits.NodeSupervisor,
      Mitbits.MinerSupervisor
    ]

    opts = [strategy: :one_for_all, name: Mitbits.Supervisor]
    Supervisor.start_link(children, opts)

    :ok
  end

  def spawn_miners({numNodes, numMiners}) do
    miner_pk_hash_sk =
      Enum.map(1..numMiners, fn _ ->
        {:ok, {sk, pk}} = RsaEx.generate_keypair()
        hash_name = Mitbits.Utility.getHash(pk)
        {:ok, _} = Mitbits.MinerSupervisor.add_miner(pk, sk, hash_name)
        {pk, hash_name, sk}
      end)

    miners =
      Enum.map(miner_pk_hash_sk, fn {_, hash_name, _} ->
        {hash_name}
      end)

    :ets.insert(:mitbits, {"miners", miners})
    {miner_pk_hash_sk, numNodes, numMiners}
  end

  def create_genesis_block({miner_pk_hash_sk, numNodes, numMiners}) do
    [{_, first_miner_hash, _} | _] = miner_pk_hash_sk

    {genesis_block} =
      GenServer.call(
        Mitbits.Utility.string_to_atom("miner_" <> first_miner_hash),
        {:mine_first, "This is starting of something big in the year 2018"}
      )

    :ets.insert(:mitbits, {"prev_block_hash", genesis_block.hash})
    {genesis_block, miner_pk_hash_sk, numNodes, numMiners}
  end

  def spawn_miner_nodes({genesis_block, miner_pk_hash_sk, numNodes, numMiners}) do
    miner_node_hash =
      Enum.map(miner_pk_hash_sk, fn {pk, hash_name, sk} ->
        {:ok, _} = Mitbits.NodeSupervisor.add_node(pk, sk, genesis_block, hash_name)

        {:ok} =
          GenServer.call(Mitbits.Utility.string_to_atom("node_" <> hash_name), :update_wallet)

        {:ok} =
          GenServer.call(
            Mitbits.Utility.string_to_atom("node_" <> hash_name),
            :add_latest_block_to_indexded_blockchain
          )

        {hash_name}
      end)

    {genesis_block, miner_node_hash, miner_pk_hash_sk, numNodes, numMiners}
  end

  def spawn_nodes_print({genesis_block, miner_node_hash, miner_pk_hash_sk, numNodes, numMiners}) do
    [{_, first_miner_hash, _} | _] = miner_pk_hash_sk

    node_hash =
      Enum.map(1..numNodes, fn _ ->
        {:ok, {sk, pk}} = RsaEx.generate_keypair()
        IO.inspect([sk, pk])
        hash_name = Mitbits.Utility.getHash(pk)

        if(hash_name != miner_node_hash) do
          {:ok, _} = Mitbits.NodeSupervisor.add_node(pk, sk, genesis_block, hash_name)

          {:ok} =
            GenServer.call(
              Mitbits.Utility.string_to_atom("node_" <> hash_name),
              :add_latest_block_to_indexded_blockchain
            )
        end

        {hash_name}
      end)

    all_nodes = miner_node_hash ++ node_hash

    # IO.inspect(node_hash)
    :ets.insert(:mitbits, {"nodes", all_nodes})

    Enum.each(node_hash, fn {hash} ->
      GenServer.cast(
        Mitbits.Utility.string_to_atom("node_" <> first_miner_hash),
        {:req_for_mitbits, 10, hash}
      )
    end)

    {node_hash, miner_node_hash, miner_pk_hash_sk, numNodes, numMiners}
  end

  def spawn_nodes({genesis_block, miner_node_hash, miner_pk_hash_sk, numNodes, numMiners}) do
    [{_, first_miner_hash, _} | _] = miner_pk_hash_sk

    node_hash =
      Enum.map(1..numNodes, fn _ ->
        {:ok, {sk, pk}} = RsaEx.generate_keypair()
        hash_name = Mitbits.Utility.getHash(pk)

        if(hash_name != miner_node_hash) do
          {:ok, _} = Mitbits.NodeSupervisor.add_node(pk, sk, genesis_block, hash_name)

          {:ok} =
            GenServer.call(
              Mitbits.Utility.string_to_atom("node_" <> hash_name),
              :add_latest_block_to_indexded_blockchain
            )
        end

        {hash_name}
      end)

    all_nodes = miner_node_hash ++ node_hash

    # IO.inspect(node_hash)
    :ets.insert(:mitbits, {"nodes", all_nodes})

    Enum.each(node_hash, fn {hash} ->
      GenServer.cast(
        Mitbits.Utility.string_to_atom("node_" <> first_miner_hash),
        {:req_for_mitbits, 10, hash}
      )
    end)

    {node_hash, miner_node_hash, miner_pk_hash_sk, numNodes, numMiners}
  end

  def get_incentive_txn({node_hash, miner_node_hash, miner_pk_hash_sk, numNodes, numMiners}) do
    {first} = Enum.at(miner_node_hash, 0)
    # IO.puts(first)
    {curr_unchained_txns} =
      GenServer.call(Mitbits.Utility.string_to_atom("node_" <> first), :get_txns)

    {curr_unchained_txns, node_hash, miner_node_hash, miner_pk_hash_sk, numNodes, numMiners}
  end

  def start_mining({node_hash, miner_node_hash, miner_pk_hash_sk, numNodes, numMiners}) do
    acc =
      Enum.reduce(miner_pk_hash_sk, 0, fn {_, miner_hash, _}, acc ->
        Mitbits.Miner.start_mining(miner_hash)
        acc + 1
      end)

    {acc, node_hash, miner_node_hash, miner_pk_hash_sk, numNodes, numMiners}
  end

  def make_transactions({acc, node_hash, miner_node_hash, miner_pk_hash_sk, numNodes, numMiners}) do
    [{_, all_nodes}] = :ets.lookup(:mitbits, "nodes")

    Enum.each(1..(acc * 2000), fn i ->
      if(i == 10000) do
        IO.puts("done")
      end

      {node1_hash} = Enum.random(all_nodes)
      {node2_hash} = Enum.random(all_nodes)
      amount = Enum.random(1..10)

      GenServer.cast(
        Mitbits.Utility.string_to_atom("node_" <> node1_hash),
        {:req_for_mitbits, amount, node2_hash}
      )
    end)

    {node_hash, miner_node_hash, miner_pk_hash_sk, numNodes, numMiners}
  end

  def print({acc, node1_hash}) do
    if acc == 5 do
      IO.inspect(
        GenServer.call(
          Mitbits.Utility.string_to_atom("node_" <> node1_hash),
          :get_indexed_blockchain
        )
      )
    end

    #      print({acc, node1_hash})
  end

  test "First mine: Genesis Block test" do
    IO.puts(
      "####################################################################################################################################################"
    )

    IO.inspect("Test Case 1: Genesis block test")

    IO.inspect(
      "Expectation: This test case will print the genesis block(that is the first block) which will has a random string and a reward transaction of 1000 Mitbits to miner"
    )

    numNodes = 0
    numMiners = 1
    :ets.new(:mitbits, [:set, :public, :named_table])

    {genesis_block, _, _, _} =
      {numNodes, numMiners}
      |> spawn_miners()
      |> create_genesis_block()

    IO.inspect(genesis_block)

    Process.sleep(100)
  end

  test "Creating public and private key" do
    IO.puts(
      "####################################################################################################################################################"
    )

    IO.inspect(
      "Test Case 2: Creating 10 participants public key, private key pairs using Elliptic-curve cryptography"
    )

    IO.inspect(
      "Expectation: Creating public keys and private keys for each user node. This test case will print 10 private keys and public keys in following format [sk,pk]. Following that will be printed the sha256 hash of public keys of the nodes visible to all other nodes"
    )

    numNodes = 10
    numMiners = 5
    :ets.new(:mitbits, [:set, :public, :named_table])

    {node_hash, _, _, _, _} =
      {numNodes, numMiners}
      |> spawn_miners()
      |> create_genesis_block()
      |> spawn_miner_nodes()
      |> spawn_nodes_print()

    IO.puts("sha256 hash of public keys")
    IO.inspect(node_hash)
    Process.sleep(100)
  end

  test "Creating transaction" do
    IO.puts(
      "####################################################################################################################################################"
    )

    IO.inspect(
      "Test Case 3: Creating 10 digitally signed transaction between 10 participants when they join the system."
    )

    IO.inspect(
      "Expectation: This test case show the structure of the transactions, also since they are the first nodes to join the system hence as incentive 10 mitbits are awarded from first gensis miner. Note the signature will be different in all txn even they are signed with same private key proving the irreversibility of the txn. This is the signature made with the private key of the first miner"
    )

    numNodes = 10
    numMiners = 5
    :ets.new(:mitbits, [:set, :public, :named_table])

    {curr_unchained_txns, _, _, _, _, _} =
      {numNodes, numMiners}
      |> spawn_miners()
      |> create_genesis_block()
      |> spawn_miner_nodes()
      |> spawn_nodes()
      |> get_incentive_txn()

    IO.inspect(curr_unchained_txns)
    Process.sleep(100)
  end

  test "Mining Bitcoins and creating block chain" do
    IO.puts(
      "####################################################################################################################################################"
    )

    IO.inspect("Test Case 4: Mining bitcoin and creating block chain")

    IO.inspect(
      "Expectation: Since mining is process creating a proof of work to approve transactions which takes computation power of each miner and all run async, this can be on-going process hence simulation is terminated after some time. Output is the mined blocks and after termination the blockchain."
    )

    numNodes = 10
    numMiners = 5
    :ets.new(:mitbits, [:set, :public, :named_table])

    {_, node_hash, _, _, _, _} =
      {numNodes, numMiners}
      |> spawn_miners()
      |> create_genesis_block()
      |> spawn_miner_nodes()
      |> spawn_nodes()
      |> start_mining()

    Process.sleep(10000)

    {first} = Enum.at(node_hash, 0)
    IO.puts("**********************************************")
    IO.puts("Printing block chain")

    {blockchain} =
      GenServer.call(Mitbits.Utility.string_to_atom("node_" <> first), :get_blockchain)

    IO.inspect(blockchain)
  end

  @tag timeout: 200_000
  test "Wallet Testing" do
    IO.puts(
      "####################################################################################################################################################"
    )

    IO.inspect(
      "Test Case 5: Testing of wallet. We run a simulation between 20 user nodes and 5 miners. 10,000 random transactions are made between any two nodes"
    )

    IO.inspect(
      "Expectation: Terminated after some time the blockchain and updated wallets of each node is printed. The blockchain contains all the valid and authentic transaction. Updated wallet is testet and compared with the txn in block of thr blockchain "
    )

    numNodes = 10
    numMiners = 5
    :ets.new(:mitbits, [:set, :public, :named_table])

    {node_hash, _, _, _, _} =
      {numNodes, numMiners}
      |> spawn_miners()
      |> create_genesis_block()
      |> spawn_miner_nodes()
      |> spawn_nodes()
      |> start_mining()
      |> make_transactions()

    Process.sleep(100_000)

    {first} = Enum.at(node_hash, 0)
    IO.puts("**********************************************")
    IO.puts("Printing Wallets of each node")

    indexed_blockchain =
      GenServer.call(Mitbits.Utility.string_to_atom("node_" <> first), :get_indexed_blockchain)

    IO.inspect(indexed_blockchain)
  end
end

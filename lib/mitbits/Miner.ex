defmodule Mitbits.Miner do
  use GenServer, restart: :transient
  @target "0000" <> "ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff"

  # API
  def start_link({pk, sk, hash_name}) do
    GenServer.start_link(__MODULE__, {pk, sk},
      name: Mitbits.Utility.string_to_atom("miner_" <> hash_name)
    )
  end

  def start_mining(hash) do
    GenServer.cast(Mitbits.Utility.string_to_atom("miner_" <> hash), :mine)
  end

  # Server
  def init({pk, sk}) do
    {:ok, {pk, sk}}
  end

  def handle_call({:mine_first, string}, _from, {pk, sk}) do
    {:ok, signature} = RsaEx.sign(string, sk)
    # {:ok, valid} = RsaEx.verify(string, signature, pk
    [{_, curr_unchained_txns}] = :ets.lookup(:mitbits, "unchained_txn")

    updated_unchained_txns =
      curr_unchained_txns ++
        [%{signature: signature, message: string, timestamp: System.system_time()}]

    :ets.insert(:mitbits, {"unchained_txn", updated_unchained_txns})

    {:reply, {mine_first(pk, sk)}, {pk, sk}}
  end

  def handle_cast(:mine, {pk, sk}) do
    [{_, curr_unchained_txns}] = :ets.lookup(:mitbits, "unchained_txn")

    sorted_unchained_txns = Enum.sort_by(curr_unchained_txns, fn txn -> txn.timestamp end)

    if Enum.count(sorted_unchained_txns) < 5 do
      GenServer.cast(self(), :mine)
      {:noreply, {pk, sk}}
    else
      {txn_set, remaining_unchained_txns} = Enum.split(sorted_unchained_txns, 5)
      str_txn_set = Mitbits.Utility.combine(txn_set)

      my_hash = Mitbits.Utility.getHash(pk)

      {prev_block_hash} =
        GenServer.call(Mitbits.Utility.string_to_atom("node_" <> my_hash), :get_prev_block_hash)

      block_string = str_txn_set <> prev_block_hash
      nonce = Enum.random(1..100)

      new_block_hash = find_block_hash(block_string, nonce)

      IO.inspect(new_block_hash)

      block = %{
        hash: new_block_hash,
        txns: txn_set,
        previous_hash: prev_block_hash,
        timestamp: System.system_time()
      }

      # IO.inspect block

      # Delete txn_set from ets
      :ets.insert(:mitbits, {"unchained_txn", remaining_unchained_txns})

      # Send block to all
      [{_, all_nodes}] = :ets.lookup(:mitbits, "nodes")

      Enum.each(all_nodes, fn {hash} ->
        IO.inspect(hash)
        {:ok} = GenServer.call(Mitbits.Utility.string_to_atom("node_" <> hash), {:rec_new_block, block})
        {:ok} = GenServer.call(Mitbits.Utility.string_to_atom("node_" <> hash), :update_wallet)
      end)

      GenServer.cast(self(), :mine)
      {:noreply, {pk, sk}}
    end
  end

  def mine_first(pk, sk) do
    [{_, curr_unchained_txns}] = :ets.lookup(:mitbits, "unchained_txn")
    :ets.insert(:mitbits, {"unchained_txn", []})
    sorted_unchained_txns = Enum.sort_by(curr_unchained_txns, fn txn -> txn.timestamp end)

    [first_txn | _] = sorted_unchained_txns
    str_signature_of_first_txn = first_txn.signature |> Base.encode16() |> String.downcase()

    str_first_txn =
      str_signature_of_first_txn <> first_txn.message <> to_string(first_txn.timestamp)

    my_hash = Mitbits.Utility.getHash(pk)
    reward_msg = %{from: "miner_" <> my_hash, to: "node_" <> my_hash, amount: 1000}

    str_reward_msg =
      to_string(reward_msg.from) <> to_string(reward_msg.to) <> to_string(reward_msg.amount)

    {:ok, signature_of_reward_txn} = RsaEx.sign(str_reward_msg, sk)
    str_signature_of_reward_txn = signature_of_reward_txn |> Base.encode16() |> String.downcase()

    reward_txn = %{
      signature: signature_of_reward_txn,
      message: reward_msg,
      timestamp: System.system_time()
    }

    str_reward_txn =
      str_signature_of_reward_txn <> str_reward_msg <> to_string(reward_txn.timestamp)

    hash_of_first_and_reward_txn = str_first_txn <> str_reward_txn

    nonce = Enum.random(1..100)

    new_block_hash = find_block_hash(hash_of_first_and_reward_txn, nonce)

    block = %{
      hash: new_block_hash,
      txns: [first_txn, reward_txn],
      previous_hash: nil,
      timestamp: System.system_time()
    }

    block
  end

  def find_block_hash(string, nonce) do
    temp_str = string <> to_string(nonce)
    temp_hash = :crypto.hash(:sha256, temp_str) |> Base.encode16() |> String.downcase()

    if(temp_hash < @target) do
      temp_hash
    else
      find_block_hash(string, nonce + 1)
    end
  end
end

defmodule Mitbits.Miner do
  use GenServer, restart: :transient
  # @target "0000" <> "ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff"
  @target "000" <> "fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff"
  # @target "00" <> "ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff"

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
    signature = Mitbits.Utility.sign(string, sk)

    updated_unchained_txn = %{
      signature: signature,
      message: string,
      timestamp: System.system_time()
    }

    {:reply, {mine_first(pk, sk, updated_unchained_txn)}, {pk, sk}}
  end

  def handle_cast(:mine, {pk, sk}) do
    my_hash = Mitbits.Utility.getHash(pk)

    {curr_unchained_txns} =
      GenServer.call(Mitbits.Utility.string_to_atom("node_" <> my_hash), :get_txns)

    authenticated_txn_list =
      Enum.reduce(curr_unchained_txns, [], fn txn, temp_list ->
        from_pk = GenServer.call(Mitbits.Utility.string_to_atom(txn.message.from), :get_pk)
        signature = txn.signature

        string = Mitbits.Utility.txn_msg_to_string(txn.message)

        indexed_blockchain =
          GenServer.call(
            Mitbits.Utility.string_to_atom("node_" <> my_hash),
            :get_indexed_blockchain
          )

        from_hash = Mitbits.Utility.string_to_atom(txn.message.from)
        balance_from_hash = Map.get(indexed_blockchain, from_hash)

        if Mitbits.Utility.verify(string, signature, from_pk) == true &&
             balance_from_hash >= txn.message.amount do
          temp_list ++ [txn]
        end
      end)

    sorted_unchained_txns = Enum.sort_by(authenticated_txn_list, fn txn -> txn.timestamp end)

    size_of_txn_set = 5

    if Enum.count(sorted_unchained_txns) < size_of_txn_set do
      GenServer.cast(self(), :mine)
      {:noreply, {pk, sk}}
    else
      my_hash = Mitbits.Utility.getHash(pk)
      {txn_set, updated_unchained_txn_set} = Enum.split(sorted_unchained_txns, size_of_txn_set)

      reward_msg = %{from: "miner_" <> my_hash, to: "node_" <> my_hash, amount: 100}

      str_reward_msg =
        to_string(reward_msg.from) <> to_string(reward_msg.to) <> to_string(reward_msg.amount)

      signature_of_reward_txn = Mitbits.Utility.sign(str_reward_msg, sk)

      reward_txn = %{
        signature: signature_of_reward_txn,
        message: reward_msg,
        timestamp: System.system_time()
      }

      txn_set = txn_set ++ [reward_txn]

      str_txn_set = Mitbits.Utility.combine(txn_set)

      [{_, prev_block_hash}] = :ets.lookup(:mitbits, "prev_block_hash")
      block_string = str_txn_set <> prev_block_hash
      nonce = Enum.random(1..100_000)

      new_block_hash = find_block_hash(block_string, nonce, prev_block_hash, my_hash)

      if(new_block_hash == :restart) do
        GenServer.cast(self(), :mine)
        {:noreply, {pk, sk}}
      else
        # IO.inspect(new_block_hash)
        :ets.insert(:mitbits, {"prev_block_hash", new_block_hash})

        block = %{
          hash: new_block_hash,
          txns: txn_set,
          previous_hash: prev_block_hash,
          timestamp: System.system_time()
        }

        {:ok} =
          GenServer.call(
            Mitbits.Utility.string_to_atom("node_" <> my_hash),
            {:delete_txns, txn_set}
          )

        IO.inspect(
          GenServer.call(
            Mitbits.Utility.string_to_atom("node_" <> my_hash),
            :get_indexed_blockchain
          )
        )

        # Send block to all
        [{_, all_nodes}] = :ets.lookup(:mitbits, "nodes")

        Enum.each(all_nodes, fn {hash} ->
          {:ok} =
            GenServer.call(
              Mitbits.Utility.string_to_atom("node_" <> hash),
              {:rec_new_block, block}
            )

          {:ok} =
            GenServer.call(
              Mitbits.Utility.string_to_atom("node_" <> hash),
              :add_latest_block_to_indexded_blockchain
            )

          {:ok} = GenServer.call(Mitbits.Utility.string_to_atom("node_" <> hash), :update_wallet)
        end)

        GenServer.cast(self(), :mine)
        {:noreply, {pk, sk}}
      end
    end
  end

  def mine_first(pk, sk, first_txn) do
    str_signature_of_first_txn = first_txn.signature |> Base.encode16() |> String.downcase()

    str_first_txn =
      str_signature_of_first_txn <> first_txn.message <> to_string(first_txn.timestamp)

    my_hash = Mitbits.Utility.getHash(pk)
    reward_msg = %{from: "miner_" <> my_hash, to: "node_" <> my_hash, amount: 1000}

    str_reward_msg =
      to_string(reward_msg.from) <> to_string(reward_msg.to) <> to_string(reward_msg.amount)

    signature_of_reward_txn = Mitbits.Utility.sign(str_reward_msg, sk)
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

    new_block_hash = find_first_block_hash(hash_of_first_and_reward_txn, nonce)
    # IO.inspect(new_block_hash)

    block = %{
      hash: new_block_hash,
      txns: [first_txn, reward_txn],
      previous_hash: nil,
      timestamp: System.system_time()
    }

    block
  end

  def find_first_block_hash(string, nonce) do
    temp_str = string <> to_string(nonce)
    temp_hash = :crypto.hash(:sha256, temp_str) |> Base.encode16() |> String.downcase()

    if(temp_hash < @target) do
      temp_hash
    else
      find_first_block_hash(string, nonce + 1)
    end
  end

  def find_block_hash(string, nonce, prev_block_hash, my_hash) do
    temp_str = string <> to_string(nonce)
    temp_hash = :crypto.hash(:sha256, temp_str) |> Base.encode16() |> String.downcase()

    [{_, temp_prev_block_hash}] = :ets.lookup(:mitbits, "prev_block_hash")
    # IO.puts nonce

    if(temp_prev_block_hash == prev_block_hash) do
      if(temp_hash < @target) do
        temp_hash
      else
        find_block_hash(string, nonce + 1, prev_block_hash, my_hash)
      end
    else
      :restart
    end
  end
end

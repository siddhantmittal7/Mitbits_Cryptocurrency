defmodule Mitbits.Node do
  use GenServer, restart: :transient

  # API
  def start_link({pk, sk, genesis_block, hash_name}) do
    GenServer.start_link(__MODULE__, {pk, sk, genesis_block},
      name: Mitbits.Utility.string_to_atom("node_" <> hash_name)
    )
  end

  def get_balance(hash) do
    GenServer.call(Mitbits.Utility.string_to_atom("node_" <> hash), :get_balance)
  end

  # Server
  def init({pk, sk, genesis_block}) do
    {:ok, {pk, sk, [genesis_block], [], 0, %{}}}
  end

  def handle_call(
        :get_indexed_blockchain,
        _from,
        {pk, sk, blockchain, txn_list, balance, indexed_blockchain}
      ) do
    {:reply, indexed_blockchain, {pk, sk, blockchain, txn_list, balance, indexed_blockchain}}
  end

  def handle_call(:get_pk, _from, {pk, sk, blockchain, txn_list, balance, indexed_blockchain}) do
    {:reply, pk, {pk, sk, blockchain, txn_list, balance, indexed_blockchain}}
  end

  def handle_call(
        :blockchain_list,
        _from,
        {pk, sk, blockchain, txn_list, balance, indexed_blockchain}
      ) do
    number_of_txns =
      Enum.reduce(blockchain, 0, fn block, count ->
        count + Enum.count(block.txns)
      end)

    {:reply, number_of_txns, {pk, sk, blockchain, txn_list, balance, indexed_blockchain}}
  end

  def handle_call(
        :get_balance,
        _from,
        {pk, sk, blockchain, txn_list, balance, indexed_blockchain}
      ) do
    {:reply, balance, {pk, sk, blockchain, txn_list, balance, indexed_blockchain}}
  end

  def handle_call(
        :compute_indexed_blockchain,
        _from,
        {pk, sk, blockchain, txn_list, balance, indexed_blockchain}
      ) do
    updated_indexed_blockchain =
      Enum.reduce(blockchain, indexed_blockchain, fn block, map ->
        txns = block.txns

        Enum.reduce(txns, map, fn txn, map ->
          if(Kernel.is_map(txn.message) == true) do
            if(txn.message.from =~ "miner") do
              {_, map} =
                Map.get_and_update(
                  map,
                  Mitbits.Utility.string_to_atom(txn.message.to),
                  fn current_value ->
                    if(current_value == nil) do
                      {current_value, txn.message.amount}
                    else
                      {current_value, current_value + txn.message.amount}
                    end
                  end
                )

              map
            else
              {_, map} =
                Map.get_and_update(
                  map,
                  Mitbits.Utility.string_to_atom(txn.message.from),
                  fn current_value ->
                    if(current_value == nil) do
                      {current_value, txn.message.amount}
                    else
                      {current_value, current_value - txn.message.amount}
                    end
                  end
                )

              {_, map} =
                Map.get_and_update(
                  map,
                  Mitbits.Utility.string_to_atom(txn.message.to),
                  fn current_value ->
                    if(current_value == nil) do
                      {current_value, txn.message.amount}
                    else
                      {current_value, current_value + txn.message.amount}
                    end
                  end
                )

              map
            end
          else
            map
          end
        end)
      end)

    {:reply, {:ok}, {pk, sk, blockchain, txn_list, balance, updated_indexed_blockchain}}
  end

  def handle_call(
        :add_latest_block_to_indexded_blockchain,
        _from,
        {pk, sk, blockchain, txn_list, balance, indexed_blockchain}
      ) do
    latest_block = Enum.at(blockchain, -1)
    latest_txns = latest_block.txns

    updated_indexed_blockchain =
      Enum.reduce(latest_txns, indexed_blockchain, fn txn, map ->
        if(Kernel.is_map(txn.message) == true) do
          if(txn.message.from =~ "miner") do
            {_, map} =
              Map.get_and_update(
                map,
                Mitbits.Utility.string_to_atom(txn.message.to),
                fn current_value ->
                  if(current_value == nil) do
                    {current_value, txn.message.amount}
                  else
                    {current_value, current_value + txn.message.amount}
                  end
                end
              )

            map
          else
            {_, map} =
              Map.get_and_update(
                map,
                Mitbits.Utility.string_to_atom(txn.message.from),
                fn current_value ->
                  if(current_value == nil) do
                    {current_value, txn.message.amount}
                  else
                    {current_value, current_value - txn.message.amount}
                  end
                end
              )

            {_, map} =
              Map.get_and_update(
                map,
                Mitbits.Utility.string_to_atom(txn.message.to),
                fn current_value ->
                  if(current_value == nil) do
                    {current_value, txn.message.amount}
                  else
                    {current_value, current_value + txn.message.amount}
                  end
                end
              )

            map
          end
        else
          map
        end
      end)

    {:reply, {:ok}, {pk, sk, blockchain, txn_list, balance, updated_indexed_blockchain}}
  end

  def handle_call(
        :update_wallet,
        _from,
        {pk, sk, blockchain, txn_list, balance, indexed_blockchain}
      ) do
    my_name = "node_" <> Mitbits.Utility.getHash(pk)

    latest_block = Enum.at(blockchain, -1)
    txns = latest_block.txns

    updated_balance =
      Enum.reduce(txns, balance, fn txn, acc ->
        if(Kernel.is_map(txn.message) == true) do
          cond do
            txn.message.from == my_name ->
              acc

            txn.message.to == my_name ->
              acc + txn.message.amount

            txn.message.from != my_name && txn.message.to != my_name ->
              acc
          end
        else
          acc
        end
      end)

    # IO.inspect(updated_balance)

    {:reply, {:ok}, {pk, sk, blockchain, txn_list, updated_balance, indexed_blockchain}}
  end

  def handle_call(
        {:buy_bitcoins, miner_node_hash},
        _from,
        {pk, sk, blockchain, txn_list, balance, indexed_blockchain}
      ) do
    GenServer.cast(
      Mitbits.Utility.string_to_atom("node_" <> miner_node_hash),
      {:req_for_mitbits, 10, Mitbits.Utility.getHash(pk)}
    )

    {:reply, {:ok}, {pk, sk, blockchain, txn_list, balance, indexed_blockchain}}
  end

  def handle_call(
        {:update_txn_set, txns},
        _from,
        {pk, sk, blockchain, txn_list, balance, indexed_blockchain}
      ) do
    updated_txns = txns
    {:reply, {:ok}, {pk, sk, blockchain, updated_txns, balance, indexed_blockchain}}
  end

  def handle_call(
        {:delete_txns, txn},
        _from,
        {pk, sk, blockchain, txn_list, balance, indexed_blockchain}
      ) do
    updated_txns = txn_list -- txn
    {:reply, {:ok}, {pk, sk, blockchain, updated_txns, balance, indexed_blockchain}}
  end

  def handle_call(
        :get_prev_block_hash,
        _from,
        {pk, sk, blockchain, txn_list, balance, indexed_blockchain}
      ) do
    latest_block = Enum.at(blockchain, -1)
    {:reply, {latest_block.hash}, {pk, sk, blockchain, txn_list, balance, indexed_blockchain}}
  end

  def handle_call(:get_txns, _from, {pk, sk, blockchain, txn_list, balance, indexed_blockchain}) do
    {:reply, {txn_list}, {pk, sk, blockchain, txn_list, balance, indexed_blockchain}}
  end

  def handle_call(
        :get_blockchain,
        _from,
        {pk, sk, blockchain, txn_list, balance, indexed_blockchain}
      ) do
    {:reply, {blockchain}, {pk, sk, blockchain, txn_list, balance, indexed_blockchain}}
  end

  def handle_call(
        :get_indexed_blockchain,
        _from,
        {pk, sk, blockchain, txn_list, balance, indexed_blockchain}
      ) do
    {:reply, indexed_blockchain, {pk, sk, blockchain, txn_list, balance, indexed_blockchain}}
  end

  def handle_call(
        {:rec_new_block, new_block},
        _from,
        {pk, sk, blockchain, txn_list, balance, indexed_blockchain}
      ) do
    updated_blockchain = blockchain ++ [new_block]

    txn_list = txn_list -- new_block.txns
    {:reply, {:ok}, {pk, sk, updated_blockchain, txn_list, balance, indexed_blockchain}}
  end

  def handle_cast(
        {:req_for_mitbits, amount, req_hash},
        {pk, sk, blockchain, txn_list, balance, indexed_blockchain}
      ) do
    if(balance >= amount) do
      txn_msg = %{
        amount: amount,
        from: "node_" <> Mitbits.Utility.getHash(pk),
        to: "node_" <> req_hash
      }

      str_txn_msg = Mitbits.Utility.txn_msg_to_string(txn_msg)

      signature_txn_msg = Mitbits.Utility.sign(str_txn_msg, sk)

      txn = %{signature: signature_txn_msg, message: txn_msg, timestamp: System.system_time()}

      updated_txn_list = txn_list ++ [txn]

      # Send block to all
      [{_, all_nodes}] = :ets.lookup(:mitbits, "nodes")

      my_hash = Mitbits.Utility.getHash(pk)

      Enum.each(all_nodes, fn {hash} ->
        # IO.inspect(hash)

        if(my_hash != hash) do
          GenServer.cast(
            Mitbits.Utility.string_to_atom("node_" <> req_hash),
            {:add_txn, txn}
          )
        end
      end)

      {:noreply, {pk, sk, blockchain, updated_txn_list, balance - amount, indexed_blockchain}}
    else
      {:noreply, {pk, sk, blockchain, txn_list, balance, indexed_blockchain}}
    end
  end

  def handle_cast({:add_txn, txn}, {pk, sk, blockchain, txn_list, balance, indexed_blockchain}) do
    updated_txns = txn_list ++ [txn]
    {:noreply, {pk, sk, blockchain, updated_txns, balance, indexed_blockchain}}
  end
end

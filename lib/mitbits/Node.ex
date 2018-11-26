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
    {:ok, {pk, sk, [genesis_block], [], 0}}
  end

  def handle_call(:get_balance, _from, {pk, sk, blockchain, txn_list, balance}) do
    {:reply, balance, {pk, sk, blockchain, txn_list, balance}}
  end

  # rewrite to iterate over just latest block
  def handle_call(:update_wallet, _from, {pk, sk, blockchain, txn_list, balance}) do
    my_name = "node_" <> Mitbits.Utility.getHash(pk)

    # IO.inspect blockchain

    balance =
      Enum.reduce(blockchain, 0, fn block, acc ->
        txns = block.txns

        tot_block =
          Enum.reduce(txns, 0, fn txn, acc ->
            if(Kernel.is_map(txn.message) == true) do
              cond do
                txn.message.from == my_name ->
                  acc - txn.message.amount

                txn.message.to == my_name ->
                  acc + txn.message.amount

                txn.message.from != my_name && txn.message.to != my_name ->
                  acc
              end
            else
              acc
            end
          end)

        acc + tot_block
      end)

    # IO.puts pk
    IO.inspect(balance)

    {:reply, {:ok}, {pk, sk, blockchain, txn_list, balance}}
  end

  def handle_call(
        {:buy_bitcoins, miner_node_hash},
        _from,
        {pk, sk, blockchain, txn_list, balance}
      ) do
    GenServer.cast(
      Mitbits.Utility.string_to_atom("node_" <> miner_node_hash),
      {:req_for_mitbits, 10, Mitbits.Utility.getHash(pk)}
    )

    {:reply, {:ok}, {pk, sk, blockchain, txn_list, balance}}
  end

  def handle_cast(
        {:req_for_mitbits, amount, req_hash},
        {pk, sk, blockchain, txn_list, balance}
      ) do
    if(balance > amount) do
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

      {:noreply, {pk, sk, blockchain, updated_txn_list, balance - amount}}
    else
      {:noreply, {pk, sk, blockchain, txn_list, balance}}
    end
  end

  def handle_call(:get_prev_block_hash, _from, {pk, sk, blockchain, txn_list, balance}) do
    latest_block = Enum.at(blockchain, -1)
    {:reply, {latest_block.hash}, {pk, sk, blockchain, txn_list, balance}}
  end

  def handle_call({:rec_new_block, new_block}, _from, {pk, sk, blockchain, txn_list, balance}) do
    updated_blockchain = blockchain ++ [new_block]
    {:reply, {:ok}, {pk, sk, updated_blockchain, txn_list, balance}}
  end

  def handle_cast({:add_txn, txn}, {pk, sk, blockchain, txn_list, balance}) do
    updated_txns = txn_list ++ [txn]
    {:noreply, {pk, sk, blockchain, updated_txns, balance}}
  end

  def handle_call({:delete_txns, txn}, _from, {pk, sk, blockchain, txn_list, balance}) do
    updated_txns = txn_list -- txn
    {:reply, {:ok}, {pk, sk, blockchain, updated_txns, balance}}
  end

  def handle_call(:get_txns, _from, {pk, sk, blockchain, txn_list, balance}) do
    {:reply, {txn_list}, {pk, sk, blockchain, txn_list, balance}}
  end
end


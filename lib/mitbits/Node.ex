defmodule Mitbits.Node do
  use GenServer, restart: :transient

  # API
  def start_link({pk, sk, genesis_block, hash_name}) do
    GenServer.start_link(__MODULE__, {pk, sk, genesis_block},
      name: Mitbits.Utility.string_to_atom("node_" <> hash_name)
    )
  end

  def get_balance(hash) do
    GenServer.call(Mitbits.Utility.string_to_atom("node_"<>hash), :get_balance)
  end

  # Server
  def init({pk, sk, genesis_block}) do
    {:ok, {pk, sk, [genesis_block], 0}}
  end

  def handle_call(:get_balance, _from, {pk,sk,blockchain,balance}) do
    {:reply, balance, {pk,sk,blockchain, balance}}
  end

  def handle_call(:update_wallet, _from, {pk, sk, blockchain, balance}) do
    my_name = "node_"<>Mitbits.Utility.getHash(pk)
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

    {:reply, {:ok}, {pk, sk, blockchain, balance}}
  end

  def handle_call({:buy_bitcoins, miner_node_hash}, _from, {pk, sk, blockchain, balance}) do
    {:ok} = GenServer.call(Mitbits.Utility.string_to_atom("node_"<>miner_node_hash), {:req_for_mitbits, 10, pk})
    {:reply, {:ok}, {pk, sk, blockchain, balance}}
  end

  def handle_call({:req_for_mitbits, amount, req_pk}, _from, {pk, sk, blockchain, balance}) do
    if(balance > amount) do
      txn_msg = %{amount: amount, from: pk, to: req_pk}
      str_txn_msg = Mitbits.Utility.txn_msg_to_string(txn_msg)

      signature_txn_msg = Mitbits.Utility.sign(str_txn_msg, sk)

      txn = %{signature: signature_txn_msg, message: txn_msg, timestamp: System.system_time()}

      {:ok} = Mitbits.Utility.add_txn(txn)

      {:reply, {:ok}, {pk, sk, blockchain, balance-amount}}
    end
  end

  def handle_call(:get_prev_block_hash, _from, {pk, sk, blockchain, balance}) do
    latest_block = Enum.at(blockchain, -1)
    {:reply, {latest_block.hash}, {pk, sk, blockchain, balance}}
  end
end

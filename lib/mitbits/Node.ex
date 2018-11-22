defmodule Mitbits.Node do
  use GenServer, restart: :transient

  # API
  def start_link({pk, sk, genesis_block}) do
    GenServer.start_link(__MODULE__, {pk, sk, genesis_block})
  end

  # Server
  def init({pk, sk, genesis_block}) do
    {:ok, {pk, sk, [genesis_block], 0}}
  end

  def handle_call(:update_wallet, _from, {pk, sk, blockchain, balance}) do
    balance =
      Enum.reduce(blockchain, 0, fn block, acc ->
        txns = block.txns

        tot_block =
          Enum.reduce(txns, 1, fn txn, acc ->
            if(Kernel.is_map(txn.message) == true) do
              cond do
                txn.message.from == pk ->
                  acc - txn.message.amount

                txn.message.to == pk ->
                  acc + txn.message.amount

                txn.message.from != pk && txn.message.to != pk ->
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

  def handle_call({:buy_bitcoins, miner_node_pid}, _from, {pk, sk, blockchain, balance}) do
    {status} = GenServer.call(miner_node_pid, {:req_for_mitbits, 10, pk})
    {:reply, {:ok}, {pk, sk, blockchain, balance}}
  end

  def handle_call({:req_for_mitbits, amount, req_pk}, _from, {pk, sk, blockchain, balance}) do
    if(balance > amount) do
      txn_msg = %{amount: amount, from: pk, to: req_pk}
      str_txn_msg = Mitbits.Utility.txn_msg_to_string(txn_msg)

      signature_txn_msg = Mitbits.Utility.sign(str_txn_msg, sk)

      txn = %{signature: signature_txn_msg, message: txn_msg, timestamp: System.system_time()}

      {:ok} = Mitbits.Utility.add_txn(txn)

      {:valid}
    else
      {:invalid}
    end
  end
end

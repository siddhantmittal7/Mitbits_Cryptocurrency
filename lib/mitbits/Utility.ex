defmodule Mitbits.Utility do
  def add_txn(txn) do
    [{_, unchained_txn}] = :ets.lookup(:mitbits, "unchained_txn")
    updated_unchained_txns = unchained_txn ++ [txn]
    :ets.insert(:mitbits, {"unchained_txn", updated_unchained_txns})
    {:ok}
  end

  def sign(string, skey) do
    {:ok, signature} = RsaEx.sign(string, skey)
    signature
  end

  def txn_msg_to_string(txn_msg) do
    to_string(txn_msg.from) <> to_string(txn_msg.to) <> to_string(txn_msg.amount)
  end

  def print_txns() do
    [{_, unchained_txn}] = :ets.lookup(:mitbits, "unchained_txn")
    IO.inspect(unchained_txn)
  end
end

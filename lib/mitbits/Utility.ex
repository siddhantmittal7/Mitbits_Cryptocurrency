defmodule Mitbits.Utility do
  def add_txn(txn) do
    [{_, unchained_txn}] = :ets.lookup(:mitbits, "unchained_txn")
    updated_unchained_txns = unchained_txn ++ [txn]
    # IO.inspect Enum.count updated_unchained_txns
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
    IO.inspect(Enum.count(unchained_txn))
  end

  def getHash(string) do
    :crypto.hash(:sha, string) |> Base.encode16() |> String.downcase()
  end

  def string_to_atom(string) do
    String.to_atom(string)
  end

  def combine(txn_set) do
    str_txn_set =
      Enum.reduce(txn_set, "", fn txn, str ->
        msg = txn.message
        str_msg = to_string(msg.from) <> to_string(msg.to) <> to_string(msg.amount)

        str_signature = txn.signature |> Base.encode16() |> String.downcase()
        str_timestamp = to_string(txn.timestamp)
        str_txn = str_msg <> str_signature <> str_timestamp
        str <> str_txn
      end)

    str_txn_set
  end
end

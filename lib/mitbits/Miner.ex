defmodule Mitbits.Miner do
  use GenServer, restart: :transient
  @target "0000" <> "ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff"

  # API
  def start_link({pk, sk}) do
    GenServer.start_link(__MODULE__, {pk, sk})
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

  def mine_first(pk, sk) do
    [{_, curr_unchained_txns}] = :ets.lookup(:mitbits, "unchained_txn")
    :ets.insert(:mitbits, {"unchained_txn", []})
    sorted_unchained_txns = List.keysort(curr_unchained_txns, 2)

    # i = Enum.count(sorted_unchained_txns)

    [first_txn | _] = sorted_unchained_txns
    str_signature_of_first_txn = first_txn.signature |> Base.encode16() |> String.downcase()

    str_first_txn =
      str_signature_of_first_txn <> first_txn.message <> to_string(first_txn.timestamp)

    reward_msg = %{from: pk, to: pk, amount: 50}

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

    new_block_hash = find_hash_first(hash_of_first_and_reward_txn, nonce)

    block = %{hash: new_block_hash, txns: [first_txn, reward_txn], previous_hash: nil}
    block
  end

  def find_hash_first(string, nonce) do
    temp_str = string <> to_string(nonce)
    temp_hash = :crypto.hash(:sha256, temp_str) |> Base.encode16() |> String.downcase()
    # IO.puts(nonce)

    if(temp_hash < @target) do
      temp_hash
    else
      find_hash_first(string, nonce + 1)
    end
  end
end

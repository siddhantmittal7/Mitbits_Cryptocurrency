defmodule Mitbits.Miner do
  use GenServer, restart: :transient
  @target "0000" <> "ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff"

  # API
  def start_link({pk, sk}) do
    GenServer.start_link(__MODULE__, {pk, sk})
  end

  def mine_first_block(string) do
    GenServer.cast(self(), {:mine_first, string})
  end

  # Server
  def init({pk, sk}) do
    # IO.inspect pk
    # IO.inspect sk
    # IO.inspect(pk, sk)
    {:ok, {pk, sk}}
  end

  def handle_cast({:mine_first, string}, {pk, sk}) do
    # IO.puts(string, sk)
    string = "gjhbsd"
    IO.inspect(string)
    # IO.puts(pk)
    # IO.puts(sk)
    {:ok, {sk, pk}} = RsaEx.generate_keypair()

    signature =
      RsaEx.sign(
        string,
        sk
      )

    IO.inspect(signature)

    {:ok, valid} =
      RsaEx.verify(
        string,
        signature,
        pk
      )

    IO.inspect(valid)
    # [{_, curr_unchained_txns}] = :ets.lookup(:mitbits, "unchained_txn")

    # updated_unchained_txns =
    #   curr_unchained_txns ++
    #     [%{signature: signature, message: string, timestamp: System.system_time()}]
    #
    # :ets.insert(:mitbits, {"unchained_txn", updated_unchained_txns})
    #
    # mine_first(pk, sk)
    {:noreply, {pk, sk}}
  end

  def mine_first(pk, sk) do
    [{_, curr_unchained_txns}] = :ets.lookup(:mitbits, "unchained_txn")
    sorted_unchained_txns = List.keysort(curr_unchained_txns, 2)

    i = Enum.count(sorted_unchained_txns)

    i =
      if(i < 50) do
        i
      else
        50
      end

    txns_to_consider =
      Enum.map(1..50, fn _ ->
        [head | tail] = sorted_unchained_txns
        sorted_unchained_txns = tail
        head
      end)

    [first_txn | tail] =
      Enum.map(txns_to_consider, fn txn ->
        txn.signature <> txn.message <> to_string(txn.timestamp)
      end)

    # txn = %{from, to, amount}
    reward_msg = %{from: :"miner_#{pk}", to: :"node_#{pk}", amount: 50}

    str_msg =
      to_string(reward_msg.from) <> to_string(reward_msg.to) <> to_string(reward_msg.amount)

    signature = Mitbits.RSA.sign(reward_msg, sk)

    reward_txn = %{signature: signature, message: reward_msg, timestamp: System.system_time()}

    txns_to_consider ++ [reward_txn]

    str_txn = first_txn <> reward_txn.signature <> str_msg <> to_string(reward_txn.timestamp)
    nonce = Enum.random(1..100)

    new_block_hash = find_hash_first(str_txn, nonce)

    IO.inspect(new_block_hash)
  end

  def find_hash_first(string, nonce) do
    temp_str = string <> to_string(nonce)
    temp_hash = :crypto.hash(:sha256, temp_str) |> Base.encode16() |> String.downcase()
    IO.puts("lol")

    if(temp_hash < @target) do
      temp_hash
    else
      find_hash_first(string, nonce + 1)
    end
  end
end

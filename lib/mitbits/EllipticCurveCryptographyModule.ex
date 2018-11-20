#How to use it


# pem_public = File.read! "ec_public_key.pem"
#pem_private = File.read! "ec_private_key.pem"
#pem = Enum.join [pem_public, pem_private]
#
#{:ok, _} = ECC.start_link pem, :ecc
#{:ok, signature} = GenServer.call :ecc, {:sign, "Hello", :sha512}
#
#{:ok, public_key} = GenServer.call :ecc, :get_public_key
#{:ok, result} = GenServer.call :ecc, {:verify_signature, "Hello", signature, public_key, :sha512}
#IO.puts "Hello == Hello? #{result}" # true
#
#{:ok, result} = GenServer.call :ecc, {:verify_signature, "World", signature, public_key, :sha512}
#IO.puts "Hello == World? #{result}" # false

#https://github.com/farao/elixir-ecc


defmodule ECC_Module do
  use GenServer

  def start(pem, register_name\\nil) do
    if register_name do
      GenServer.start(__MODULE__, pem, name: register_name)
    else
      GenServer.start(__MODULE__, pem)
    end
  end

  def start_link(pem, register_name\\nil) do
    if register_name do
      GenServer.start_link(__MODULE__, pem, name: register_name)
    else
      GenServer.start_link(__MODULE__, pem)
    end
  end

  def init(pem) do
    {:ok, %{
      public: ECC.Crypto.parse_public_key(pem),
      private: ECC.Crypto.parse_private_key(pem)
    }}
  end

  def handle_call(:get_public_key, _from, keys) do
    if keys.public do
      {:reply, {:ok, keys.public}, keys}
    else
      {:reply, {:error, :no_public_key}, keys}
    end
  end

  def handle_call({:sign, msg, hash_type}, _from, keys) do
    {:reply, {:ok, ECC.Crypto.sign(msg, hash_type, keys.private)}, keys}
  end

  def handle_call({:verify_signature, msg, signature, public_key, hash_type}, _from, keys) do
    result = ECC.Crypto.verify_signature(msg, signature, hash_type, public_key)
    {:reply, {:ok, result}, keys}
  end
end

defmodule ECC.Crypto do
  def parse_public_key(pem) do
    try do
      pem_keys = :public_key.pem_decode(pem)

      ec_params =
        Enum.find(pem_keys, fn(k) -> elem(k,0) == :OTPEcpkParameters end)
        |> put_elem(0, :EcpkParameters)
        |> :public_key.pem_entry_decode

      pem_public =
        Enum.find(pem_keys, fn(k) -> elem(k,0) == :SubjectPublicKeyInfo end)
        |> elem(1)
      ec_point = :public_key.der_decode(:SubjectPublicKeyInfo, pem_public)
                 |> elem(2)
                 |> elem(1)

      {{:ECPoint, ec_point}, ec_params}
    rescue
      _ -> nil
    end
  end

  def parse_private_key(pem) do
    try do
      :public_key.pem_decode(pem)
      |> Enum.find(fn(k) -> elem(k,0) == :ECPrivateKey end)
      |> :public_key.pem_entry_decode
    rescue
      _ -> nil
    end
  end

  def sign(msg, hash_type, private_key) do
    try do
      :public_key.sign msg, hash_type, private_key
    rescue
      _ -> nil
    end
  end

  def verify_signature(msg, signature, hash_type, public_key) do
    try do
      :public_key.verify(msg, hash_type, signature, public_key)
    rescue
      _ -> nil
    end
  end
end

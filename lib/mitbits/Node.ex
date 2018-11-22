defmodule Mitbits.Node do
  use GenServer, restart: :transient

  # API
  def start_link({pk, sk}) do
    GenServer.start_link(__MODULE__, {pk, sk})
  end

  # Server
  def init({pk, sk}) do
    {:ok, {pk, sk, %{}}}
  end
end

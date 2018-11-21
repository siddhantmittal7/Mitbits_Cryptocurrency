defmodule Mitbits.Application do
  use Application

  def start(_type) do
    children = [
      Mitbits.NodeSupervisor,
      Mitbits.MinerSupervisor,
      Mitbits.Driver
    ]

    opts = [strategy: :one_for_all, name: Mitbits.Supervisor]
    Supervisor.start_link(children, opts)
  end
end

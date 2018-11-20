defmodule Chord.Application do
  use Application

  def start(_type, {numNodes, numRequests}) do
    children = [
      Chord.NodeSupervisor,
      Chord.Stabilize,
      {Chord.Driver, {numNodes, numRequests, 0}}
    ]

    opts = [strategy: :one_for_all, name: Chord.Supervisor]
    Supervisor.start_link(children, opts)
  end
end

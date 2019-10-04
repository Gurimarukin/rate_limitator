defmodule RateLimitator.Application do
  @moduledoc false

  use Application

  def start(_type, _args) do
    children = [
      {DynamicSupervisor, name: RateLimitator.LimitersSupervisor, strategy: :one_for_one}
    ]

    opts = [strategy: :one_for_one, name: RateLimitator.Supervisor]
    Supervisor.start_link(children, opts)
  end
end

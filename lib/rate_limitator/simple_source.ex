defmodule RateLimitator.SimpleSource do
  use GenStage

  def start_link(opts \\ []) do
    GenStage.start_link(__MODULE__, :ok, opts)
  end

  def init(:ok) do
    {:producer, 0}
  end

  def handle_demand(demand, counter) when demand > 0 do
    events = counter..(counter + demand - 1) |> Enum.map(&job/1)
    {:noreply, events, counter + demand}
  end

  defp job(i), do: fn -> IO.puts(i) end
end

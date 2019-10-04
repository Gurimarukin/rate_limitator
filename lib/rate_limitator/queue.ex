defmodule RateLimitator.Queue do
  use GenStage

  @spec start_link([{:name, atom}]) :: any
  def start_link(opts \\ []) do
    GenStage.start_link(__MODULE__, :ok, opts)
  end

  @impl true
  def init(:ok) do
    {:producer, :queue.new()}
  end

  def unquote(:in)(queue, elt) do
    GenStage.call(queue, {:in, elt})
  end

  @impl true
  def handle_call({:in, elt}, _from, queue) do
    queue = :queue.in(elt, queue)
    {:reply, :ok, [], queue}
  end

  @impl true
  def handle_demand(demand, queue) when demand > 0 do
    {queue, events} = out(queue, demand)
    {:noreply, events, queue}
  end

  defp out(queue, size), do: out_rec(queue, size, [])

  defp out_rec(queue, size, acc) when size <= 0 do
    {queue, acc}
  end

  defp out_rec(queue, size, acc) do
    {elt, queue} = :queue.out(queue)

    case elt do
      :empty -> {queue, acc}
      {:value, value} -> out_rec(queue, size - 1, acc ++ [value])
    end
  end
end

defmodule RateLimitator.Scheduler do
  use GenStage

  @spec start_link({atom, [{:max_demand, number} | {:interval, number}], []}) :: any
  def start_link({queue_name, args, opts}) do
    GenStage.start_link(__MODULE__, {queue_name, args}, opts)
  end

  @impl true
  def init({queue_name, args}) do
    args = %{
      max_demand: args[:max_demand] || 5,
      interval: args[:interval] || 1000
    }

    {:consumer, {args, %{}}, subscribe_to: [queue_name]}
  end

  @impl true
  def handle_subscribe(:producer, _opts, from, {args, _}) do
    producer = %{
      producer: from,
      pending: args.max_demand
    }

    {:manual, ask_and_schedule({args, producer})}
  end

  @impl true
  def handle_cancel(_, _from, {args, _}) do
    {:noreply, [], {args, nil}}
  end

  @impl true
  def handle_events(events, _from, {args, producer}) do
    producer = Map.update!(producer, :pending, &(&1 - length(events)))

    events
    |> Enum.map(& &1.())

    {:noreply, [], {args, producer}}
  end

  @impl true
  def handle_info(:ask, {args, producer}) do
    state = {args, Map.update!(producer, :pending, fn _ -> args.max_demand end)}
    {:noreply, [], ask_and_schedule(state)}
  end

  defp ask_and_schedule({args, producer}) do
    GenStage.ask(producer.producer, producer.pending)
    Process.send_after(self(), :ask, args.interval)
    {args, producer}
  end
end

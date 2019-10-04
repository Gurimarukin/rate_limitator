defmodule RateLimitator.Limiter do
  @moduledoc """
  ## Example

      iex> {:ok, pid} = Limiter.start_link({[max_demand: 3, interval: 2000], []})
      iex> 1..5
      ...> |> Enum.map(&Limiter.submit(pid, fn -> &1 end))
      ...> |> Enum.map(&Task.await/1)
      [1, 2, 3, 4, 5]
  """

  use GenServer

  alias RateLimitator.{Scheduler, Queue}

  @doc """
  Starts the Limiter.

  ## Arguments

    * `scheduler_args` arguments passed down to `RateLimitator.Scheduler`
    * `opts` - options for `GenServer.start_link/3`
  """
  @spec start_link({[{:max_demand, number} | {:interval, number}], [{:name, atom}]}) :: {:ok, pid}
  def start_link({scheduler_args, opts}) do
    GenServer.start_link(__MODULE__, scheduler_args, opts)
  end

  @doc """
  Starts a `Supervisor` for a registered `RateLimitator.Queue` and a `RateLimitator.Scheduler`, so that the scheduler can subscribe to the queue.
  """
  @spec init([{:max_demand, number} | {:interval, number}]) :: {:ok, {term, term}}
  @impl true
  def init(scheduler_args) do
    id = UUID.uuid1(:hex)
    queue_name = {:via, Registry, {Registry.Queues, id}}
    scheduler_name = {:via, Registry, {Registry.Schedulers, id}}

    children = [
      {Queue, [name: queue_name]},
      {Scheduler, {queue_name, scheduler_args, [name: scheduler_name]}}
    ]

    Supervisor.start_link(children, strategy: :rest_for_one)

    {:ok, {queue_name, scheduler_name}}
  end

  @doc """
  Submits job to the limiter.

  Returns a async `Task` which must be awaited to get the result.
  """
  @spec submit(atom | pid | {atom, any} | {:via, atom, any}, any) :: any
  def submit(limiter, job) do
    Task.async(fn ->
      GenServer.call(limiter, {:submit, get_job(job, self())})

      receive do
        {:result, result} -> result
      end
    end)
  end

  defp get_job(job, parent) do
    fn ->
      Task.start_link(fn -> send(parent, {:result, job.()}) end)
    end
  end

  def update_scheduler_args(limiter, scheduler_args) do
    GenServer.call(limiter, {:update_scheduler_args, scheduler_args})
  end

  @impl true
  def handle_call({:submit, job}, _from, {queue_name, scheduler_name}) do
    Queue.in(queue_name, job)
    {:reply, :ok, {queue_name, scheduler_name}}
  end

  @impl true
  def handle_call({:update_scheduler_args, scheduler_args}, _from, {queue_name, scheduler_name}) do
    Scheduler.update_args(scheduler_name, scheduler_args)
    {:reply, :ok, {queue_name, scheduler_name}}
  end
end

defmodule RateLimitator.Limiter do
  use GenServer

  alias RateLimitator.{Scheduler, Queue}

  @spec start_link({atom, [{:max_demand, number} | {:interval, number}], [{:name, atom}]}) ::
          {:ok, pid}
  def start_link({name, scheduler_args, opts}) do
    GenServer.start_link(__MODULE__, {name, scheduler_args}, opts)
  end

  @impl true
  def init({name, scheduler_args}) do
    full_name = Module.concat(Queue, name)

    children = [
      Supervisor.child_spec({Queue, [name: full_name]}, id: {Queue, name}),
      Supervisor.child_spec({Scheduler, {full_name, scheduler_args, []}}, id: {Scheduler, name})
    ]

    Supervisor.start_link(children, strategy: :rest_for_one)

    {:ok, full_name}
  end

  def submit(limiter, job) do
    GenServer.call(limiter, {:submit, job})
  end

  @impl true
  def handle_call({:submit, job}, _from, name) do
    Queue.in(name, job)
    {:reply, :ok, name}
  end
end

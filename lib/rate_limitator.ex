defmodule RateLimitator do
  @moduledoc """
  `RateLimitator` provides a wrappers arround `RateLimitator.Limiter` to avoid having to start it by hand and pass it everywhere.

  You still can create a `RateLimitator.Limiter` by hand.

  ## Example

      iex> 1..5
      ...> |> Enum.map(&RateLimitator.with_limit(:my_limiter, fn -> IO.inspect(&1) end, max_demand: 3, interval: 1000))
      ...> |> Enum.map(&Task.await/1)
      [1, 2, 3, 4, 5]
      iex> RateLimitator.stop(:my_limiter)
      :ok
      iex> RateLimitator.stop(:my_limiter)
      {:ok, :already_stopped}
      iex> RateLimitator.with_limit(:my_limiter, fn -> :toto end) |> Task.await
      :toto

  """

  alias RateLimitator.Limiter

  @limiters_supervisor RateLimitator.LimitersSupervisor

  @doc """
  Tries to start a supervised `Limiter` with name `name`.
  Uses the created `Limiter` or the existing one if it already exists, to submit the job to it.

  Calling `with_limit/3` with one or more `scheduler_args` overwrites **all** the current `args` of the `Scheduler` (using the defaults for the one not provided).

  An async `Task` is returned, which must be awaited to get the result of the job.

  ## Options

    * `:max_demand` - (number) the max calls which can be done in `interval`, default: 5
    * `:interval` - (number) in milliseconds, default: 1000
  """
  @spec with_limit(atom, (none -> any), [{:max_demand, number} | {:interval, number}]) :: Task.t()
  def with_limit(name, job, scheduler_args \\ []) do
    limiter(name, scheduler_args) |> Limiter.submit(job)
  end

  defp limiter(name, scheduler_args) do
    case DynamicSupervisor.start_child(
           @limiters_supervisor,
           {Limiter, {scheduler_args, [name: full_name(name)]}}
         ) do
      {:ok, limiter} ->
        limiter

      {:error, {:already_started, limiter}} ->
        if scheduler_args != [], do: Limiter.update_scheduler_args(limiter, scheduler_args)
        limiter
    end
  end

  defp full_name(name), do: Module.concat(Limiter, name)

  @spec whereis(atom) :: nil | pid | {atom, atom}
  def whereis(name), do: GenServer.whereis(full_name(name))

  @spec stop(atom) :: :ok | {:ok, :already_stopped} | {:error, :not_found}
  def stop(name) do
    pid = whereis(name)

    if pid != nil do
      DynamicSupervisor.terminate_child(@limiters_supervisor, pid)
    else
      {:ok, :already_stopped}
    end
  end

  def dummy_job(i) do
    Process.sleep(2000)
    IO.inspect(i)
  end
end

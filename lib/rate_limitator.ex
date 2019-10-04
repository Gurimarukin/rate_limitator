defmodule RateLimitator do
  @moduledoc """
  Provides a rate limiter for jobs.

  ## Example

      iex> 1..5
      ...> |> Enum.map(&RateLimitator.with_limit(:my_limiter, fn -> &1 end, max_demand: 3, interval: 500))
      ...> |> Enum.map(&Task.await/1)
      [1, 2, 3, 4, 5]
      iex> RateLimitator.stop(:my_limiter)
      :ok
      iex> RateLimitator.stop(:my_limiter)
      {:ok, :already_stopped}

      iex> RateLimitator.with_limit(:my_limiter, fn -> :toto end) |> Task.await
      :toto

  """
  # use GenServer

  alias RateLimitator.Limiter

  @supervisor RateLimitator.LimitersSupervisor

  @spec with_limit(atom, (none -> any), [{:max_demand, number} | {:interval, number}]) :: Task.t()
  def with_limit(name, job, scheduler_args \\ []) do
    Task.async(fn ->
      limiter(name, scheduler_args)
      |> Limiter.submit(get_job(job, self()))

      receive do
        {:result, result} -> result
      end
    end)
  end

  defp limiter(name, scheduler_args) do
    full_name = Module.concat(Limiter, name)

    case DynamicSupervisor.start_child(
           @supervisor,
           {Limiter, {name, scheduler_args, [name: full_name]}}
         ) do
      {:ok, pid} -> pid
      {:error, {:already_started, pid}} -> pid
    end
  end

  defp get_job(job, parent) do
    fn ->
      Task.start_link(fn ->
        result = job.()
        send(parent, {:result, result})
      end)
    end
  end

  def whereis(name) do
    GenServer.whereis(Module.concat(Limiter, name))
  end

  def stop(name) do
    pid = whereis(name)

    if pid != nil do
      DynamicSupervisor.terminate_child(@supervisor, pid)
    else
      {:ok, :already_stopped}
    end
  end

  def dummy_job(i) do
    Process.sleep(2000)
    IO.inspect(i)
  end
end

defmodule RateLimitatorTest do
  use ExUnit.Case
  doctest RateLimitator

  test "creates limiters" do
    assert RateLimitator.whereis(:limiter1) == nil
    assert RateLimitator.whereis(:limiter2) == nil

    res = RateLimitator.with_limit(:limiter1, fn -> :toto end) |> Task.await()
    assert res == :toto

    assert RateLimitator.whereis(:limiter1) != nil
    assert RateLimitator.whereis(:limiter2) == nil

    res = RateLimitator.with_limit(:limiter2, fn -> :toto end) |> Task.await()
    assert res == :toto

    assert RateLimitator.whereis(:limiter1) != nil
    assert RateLimitator.whereis(:limiter2) != nil

    assert RateLimitator.stop(:limiter1) == :ok

    assert RateLimitator.whereis(:limiter1) == nil
    assert RateLimitator.whereis(:limiter2) != nil

    assert RateLimitator.stop(:limiter2) == :ok

    assert RateLimitator.whereis(:limiter1) == nil
    assert RateLimitator.whereis(:limiter2) == nil

    assert RateLimitator.stop(:limiter2) == {:ok, :already_stopped}

    before = Time.utc_now()

    res =
      1..6
      |> Enum.map(
        &RateLimitator.with_limit(:limiter, fn -> &1 end,
          max_demand: 3,
          interval: 500
        )
      )
      |> Enum.map(&Task.await/1)

    diff = Time.diff(Time.utc_now(), before, :millisecond)

    assert res == [1, 2, 3, 4, 5, 6]
    assert diff >= 1000
    assert diff < 1500
  end
end

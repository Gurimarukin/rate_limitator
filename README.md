# RateLimitator

Simple example:
```ex
1..50
|> Enum.map(&RateLimitator.with_limit(:my_limiter, fn -> IO.inspect(&1) end, max_demand: 3, interval: 1000))
# |> Enum.map(&Task.await/1)
```

Under the hood, a `Limiter` is started with the name `:my_limiter` (if it doesn't already exists). You need to stop it before changing the parameters given in `RateLimitator.with_limit/3` as they are taken into account only if no named `Limiter` exists.

```ex
RateLimitator.stop(:my_limiter)
```

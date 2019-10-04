defmodule RateLimitator.MixProject do
  use Mix.Project

  def project do
    [
      app: :rate_limitator,
      version: "1.0.0",
      elixir: "~> 1.9",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  def application do
    [
      extra_applications: [:logger],
      mod: {RateLimitator.Application, []}
    ]
  end

  defp deps do
    [
      {:gen_stage, "~> 0.14"}
    ]
  end
end

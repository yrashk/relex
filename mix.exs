defmodule Relex.Mixfile do
  use Mix.Project

  def project do
    [ app: :relex,
      version: "0.0.1",
      elixir: ">= 0.12.4",
      deps: deps ]
  end

  # Configuration for the OTP application
  def application do
    [applications: ~w(sasl)a]
  end

  defp deps do
    []
  end
end

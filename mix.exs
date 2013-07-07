defmodule Relex.Mixfile do
  use Mix.Project

  def project do
    [ app: :relex,
      version: "0.0.1",
      elixir: "~> 0.9.4-dev",
      deps: deps ]
  end

  # Configuration for the OTP application
  def application do
    []
  end

  defp deps do
    []
  end
end

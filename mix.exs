defmodule Relex.Mixfile do
  use Mix.Project

  def project do
    [ app: :relex,
      version: "0.0.1",
      deps: deps ]
  end

  # Configuration for the OTP application
  def application do
    [description: 'Release assembler', registered: []]
  end

  defp deps do
    []
  end
end

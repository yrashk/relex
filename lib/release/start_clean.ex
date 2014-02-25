defmodule Relex.Release.StartClean do
  use Relex.Release

  def name, do: "start_clean"
  def version, do: "1.0"
  def basic_applications(_options), do: %w(kernel stdlib)a
  def applications, do: []
  def include_erts?, do: false
  def include_elixir?, do: false
end

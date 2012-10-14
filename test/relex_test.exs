Code.require_file "../test_helper.exs", __FILE__

defmodule TestRelease do
  use Relex.Release

  def name, do: "test_rel"
  def version, do: "1.0"
end

defmodule RelexTest do
  use ExUnit.Case

  def setup_all do
    File.mkdir_p!(path)
    path
  end

  def teardown_all(path) do
    File.rm_rf! path
  end

  test "basic module sanity test" do
    assert Code.ensure_loaded?(TestRelease) == true
  end

  test "assembly of a minimal release" do
    assert TestRelease.assemble!(path: path) == :ok
  end

  defp path, do: File.join(File.dirname(__FILE__), "tmp")
end

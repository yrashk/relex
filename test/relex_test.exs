Code.require_file "../test_helper.exs", __ENV__.file

defmodule TestRelease do
  use Relex.Release

  def name, do: "test_rel"
  def version, do: "1.0"
end

defmodule TestRelease.StartClean do
  use Relex.Release

  def name, do: "test_start_clean"
  def version, do: "1.0"
  def include_start_clean?, do: true
end

defmodule TestRelease.StartClean.AsDefault do
  use Relex.Release

  def name, do: "test_start_clean_default"
  def version, do: "1.0"
  def include_start_clean?, do: true
  def default_release?, do: false
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

  test "assembly of a release including start_clean" do
    assert TestRelease.StartClean.assemble!(path: path) == :ok
  end

  test "assembly of a release including start_clean as default" do
    assert TestRelease.StartClean.AsDefault.assemble!(path: path) == :ok
  end

  defp path, do: Path.join(Path.dirname(__ENV__.file), "tmp")
end

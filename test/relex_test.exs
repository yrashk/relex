Code.require_file "../test_helper.exs", __FILE__

defmodule TestRelease do
  use Relex.Release

  def name, do: "test_rel"
  def version, do: "1.0"
end

defmodule RelexTest do
  use ExUnit.Case

  test "basic module sanity test" do
    assert Code.ensure_loaded?(TestRelease) == true
  end
end

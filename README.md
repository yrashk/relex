# Relex — Release assembler

Relex is a simplistic assembler for Erlang releases in Elixir.

In order to define a release, this is your start point:

```elixir
defmodule MyApp.Release do
  use Relex.Release

  def name, do: "myapp"
  def version, do: "1"

  def applications, do: [:myapp]
end
```

See Relex.Release file for more callbacks

After having this module compiled, run `MyApp.Release.make! path: "/output/dir"` (path is optional)
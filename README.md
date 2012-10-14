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

See Relex.Release.Template documentation for more information

After having this module compiled, run `MyApp.Release.assemble! path: "/output/dir"` (path is optional)
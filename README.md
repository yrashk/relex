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

## Mix task

You can also use Relex with Mix. For this, add the following dependency:

```elixir
{:relex, github: "yrashk/relex"},
```

Then, prepend your mix.exs file with this:

```elixir
Code.append_path "deps/relex/ebin"
```

and then, inside of your project module, define the release:

```elixir
if Code.ensure_loaded?(Relex.Release) do
  defmodule Release do
    use Relex.Release

    def name, do: "myrelease"
    def version, do: Mix.project[:version]
    def applications, do: [:myapp]
    def lib_dirs, do: ["deps"]
  end
end
```

Now you can run `mix relex.assemble` and `mix relex.clean` commands

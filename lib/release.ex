defmodule Relex.Release do
  defmodule Behaviour do
    use Behaviour
    defcallback name
    defcallback version
    defcallback applications
  end

  defmacro __using__(_) do
    quote do
      import Relex.Release
      @behaviour Relex.Release.Behaviour

      def basic_applications do
        [:kernel, :stdlib, :sasl]
      end

      def applications do
        []
      end

      def rel do
        rel(__MODULE__)
      end

      def erts_version do
        list_to_binary(:erlang.system_info(:version))
      end

      defoverridable basic_applications: 0, applications: 0, rel: 0, erts_version: 0

    end
  end


  def rel(release) do
    {:release, {to_char_list(release.name), to_char_list(release.version)},
               {:erts, to_char_list(release.erts_version)},
               (lc app inlist apps(release) do
                  {Relex.App.name(app), Relex.App.version(app), 
                   Relex.App.type(app), 
                   lc inc_app inlist Relex.App.included_applications(app), do: Relex.App.name(inc_app)}
               end)}
  end

  defp apps(release) do
    requirements = release.basic_applications ++ release.applications
    apps = lc req inlist requirements, do: Relex.App.new(req)
    deps = List.flatten(lc app inlist apps, do: deps(app))
    apps = List.uniq(apps ++ deps)
    Dict.values(Enum.reduce apps, HashDict.new, 
                fn(app, acc) ->
                  name = Relex.App.name(app)
                  if existing_app = Dict.get(acc, name) do
                    if Relex.App.version(app) >
                       Relex.App.version(existing_app) do
                      Dict.put(acc, name, app)
                    else
                      acc
                    end  
                  else
                    Dict.put(acc, name, app)
                  end
                end)
  end

  defp deps(app) do
    deps = Relex.App.dependencies(app)
    deps = deps ++ (lc app inlist deps, do: deps(app))
    List.flatten(deps)
  end

end
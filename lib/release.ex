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

      def rel, do: rel(__MODULE__)
      def write_script!(opts // []), do: write_script!(__MODULE__, opts)
      def bundle!(kind, opts // []), do: bundle!(kind, __MODULE__, opts)

      def make!(opts // []) do
        __MODULE__.write_script!(opts)
        __MODULE__.bundle!(:applications, opts)
        __MODULE__.bundle!(:erts, opts)
      end

      def erts_version do
        list_to_binary(:erlang.system_info(:version))
      end

      def code_path do
        lc path inlist :code.get_path, do: list_to_binary(path)
      end

      def root_dir do
        list_to_binary(:code.root_dir)
      end

      defoverridable basic_applications: 0, applications: 0, rel: 0, erts_version: 0, code_path: 0, root_dir: 0

    end
  end

  def bundle!(:erts, release, options) do
    path = File.join([options[:path] || File.cwd!, release.name, "lib"])
    erts_vsn = "erts-#{release.erts_version}"
    erts = File.join(release.root_dir, erts_vsn)
    unless File.exists?(erts) do
     {:error, :erts_not_found}
    else
      target = File.join(path, erts_vsn)
      File.mkdir_p!(target)
      File.cp_r!(File.join(erts,"."), target)
      fix_permissions!(erts, target)
    end
    :ok
  end
  def bundle!(:applications, release, options) do
    path = File.join([options[:path] || File.cwd!, release.name, "lib"])
    apps = apps(release)
    lc app inlist apps do
      target = File.join(path, "#{Relex.App.name(app)}-#{Relex.App.version(app)}")
      File.mkdir_p!(target)
      path = Relex.App.path(app)
      File.cp_r!(File.join(path,"."), target)
      fix_permissions!(path, target)
    end
    :ok
  end

  def write_script!(release, options) do
    path = File.join([options[:path] || File.cwd!, release.name, "releases", release.version])
    File.mkdir_p! path
    rel_file = File.join(path, "#{release.name}.rel")
    File.write rel_file, :io_lib.format("~p.~n",[rel(release)])
    code_path = lc path inlist release.code_path, do: to_char_list(path)
    :systools.make_script(to_char_list(File.join(path, release.name)), [path: code_path, outdir: to_char_list(path)])
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

  # workaround for File.cp_r! not respecting permissions
  defp fix_permissions!(src, dst) do
    src_split = File.split(src)
    files = File.wildcard(File.join([src, "**", "**"]))
    lc file inlist files do
      stat = File.stat!(file)
      rel_path = File.join(:lists.nthtail(length(src_split), File.split(file)))
      File.write_stat!(File.join([dst, rel_path]), stat)
    end
  end

end
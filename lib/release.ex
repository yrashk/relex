defexception Relex.Error, message: nil

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

      def write_script!(opts // []), do: write_script!(__MODULE__, opts)
      def bundle!(kind, opts // []), do: bundle!(kind, __MODULE__, opts)

      def make!(opts // []) do
        write_script!(opts)
        bundle!(:applications, opts)
        bundle!(:erts, opts)
        after_bundle(opts)
      end

      def name(_), do: name
      def version(_), do: version

      defcallback basic_applications do
        [:kernel, :stdlib, :sasl]
      end

      defcallback applications do
        []
      end

      defcallback erts_version do
        list_to_binary(:erlang.system_info(:version))
      end

      defcallback code_path do
        lc path inlist :code.get_path, do: list_to_binary(path)
      end

      defcallback root_dir do
        list_to_binary(:code.root_dir)
      end

      defcallback include_application?(app), do: true

      def after_bundle(opts) do
        Relex.Helper.MinimalStarter.render(__MODULE__, opts)
      end

      defoverridable name: 1, version: 1,
                     after_bundle: 1

    end
  end

  def bundle!(:erts, release, options) do
    path = File.join([options[:path] || File.cwd!, release.name(options), "lib"])
    erts_vsn = "erts-#{release.erts_version(options)}"
    erts = File.join(release.root_dir(options), erts_vsn)
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
    path = File.expand_path(File.join([options[:path] || File.cwd!, release.name(options), "lib"]))
    apps = apps(release, options)
    lc app inlist apps do
      source = File.expand_path(Relex.App.path(app))
      source_len = byte_size(source)
      if match?(<<^source :: [binary, size(source_len)], _ :: binary>>, path) do
        raise Relex.Error, message: "Can't create the release inside #{Relex.App.name(app)} application (#{source})"
      end
      target = File.join(path, "#{Relex.App.name(app)}-#{Relex.App.version(app)}")
      File.mkdir_p!(target)
      File.cp_r!(File.join(source,"."), target)
      fix_permissions!(source, target)
    end
    :ok
  end

  def write_script!(release, options) do
    path = File.join([options[:path] || File.cwd!, release.name(options), "releases", release.version(options)])
    File.mkdir_p! path
    rel_file = File.join(path, "#{release.name(options)}.rel")
    File.write rel_file, :io_lib.format("~p.~n",[rel(release, options)])
    code_path = lc path inlist release.code_path, do: to_char_list(path)
    :systools.make_script(to_char_list(File.join(path, release.name(options))), [path: code_path, outdir: to_char_list(path)])
  end

  def rel(release, options) do
    {:release, {to_char_list(release.name(options)), to_char_list(release.version(options))},
               {:erts, to_char_list(release.erts_version(options))},
               (lc app inlist apps(release, options) do
                  {Relex.App.name(app), Relex.App.version(app), 
                   Relex.App.type(app), 
                   lc inc_app inlist Relex.App.included_applications(app), do: Relex.App.name(inc_app)}
               end)}
  end

  defp apps(release, options) do
    requirements = release.basic_applications(options) ++ release.applications(options)
    apps = lc req inlist requirements, do: Relex.App.new(req)
    deps = List.flatten(lc app inlist apps, do: deps(app))
    apps = List.uniq(apps ++ deps)
    apps = 
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
    Enum.filter apps, fn(app) -> release.include_application?(options, Relex.App.name(app)) end
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

  defmacro defcallback({callback_name, _, args}, opts) do
    if is_atom(args), do: args = []
    full_args = [(quote do: _)|args]
    sz = length(args)
    quote do
      def unquote(callback_name)(unquote_splicing(full_args)) do
        unquote(callback_name)(unquote_splicing(args))
      end
      def unquote(callback_name)(unquote_splicing(args)), unquote(opts)
      defoverridable [{unquote(callback_name), unquote(sz)}, 
                      {unquote(callback_name), unquote(sz+1)}]
    end
  end

end
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

      def assemble!(opts // []) do
        bundle!(:applications, opts)
        if include_erts?(opts), do: bundle!(:erts, opts)
        write_script!(opts)        
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
      def code_path(options) do
        ebins = List.flatten(lc path inlist lib_dirs(options) do
                               File.wildcard(File.join([File.expand_path(path),"**","ebin"]))
                             end)
        ebins ++ code_path
      end

      defcallback lib_dirs, do: []

      defcallback root_dir do
        list_to_binary(:code.root_dir)
      end

      defcallback include_application?(app), do: true

      defcallback include_erts_file?(file) do
        regexes = [%r(^bin/.+), %r(^lib/.+), %r(^include/.+), %r(^info$)]        
        Enum.any?(regexes, Regex.match?(&1, file))
      end

      defcallback include_app_file?(file) do
        regexes = [%r(^ebin/.*), %r(^priv/.+), %r(^include/.+)]
        Enum.any?(regexes, Regex.match?(&1, file))
      end

      defcallback include_erts?, do: true

      defcallback default_release?, do: true

      defcallback relocatable?, do: true

      def after_bundle(opts) do
        Relex.Helper.MinimalStarter.render(__MODULE__, opts)
      end

      defoverridable name: 1, version: 1,
                     after_bundle: 1

    end
  end

  def bundle!(:erts, release, options) do
    path = File.join([options[:path] || File.cwd!, release.name(options)])
    erts_vsn = "erts-#{release.erts_version(options)}"
    src = File.join(release.root_dir(options), erts_vsn)
    unless File.exists?(src) do
     {:error, :erts_not_found}
    else
      target = File.join(path, erts_vsn)
      files = Enum.filter(File.wildcard(File.join([src, "**", "**"])),
                          fn(file) -> 
                            release.include_erts_file?(options, Relex.Files.relative_path(src, file)) 
                          end)
      Relex.Files.copy(files, src, target)
      if release.relocatable?(options) do
        templates = File.wildcard(File.join([target, "bin", "*.src"]))
        lc template inlist templates do 
          content = File.read!(template)
          new_content = String.replace(content, "%FINAL_ROOTDIR%", "$(cd ${0%/*} && pwd)/../..", global: true)
          new_file = File.join([target, "bin", File.basename(template, ".src")])
          File.write!(new_file, new_content)
          stat = File.stat!(template)
          File.write_stat!(new_file, File.Stat.mode(493, stat))
        end
      end
    end
    :ok
  end
  def bundle!(:applications, release, options) do
    path = File.expand_path(File.join([options[:path] || File.cwd!, release.name(options), "lib"]))
    apps = apps(release, options)
    apps_files = lc app inlist apps do
      src = File.expand_path(Relex.App.path(app))
      files = Enum.filter(File.wildcard(File.join([src, "**", "**"])),
                         fn(file) -> release.include_app_file?(options, Relex.Files.relative_path(src, file)) end)
      {app, src, files}
    end
    lc {app, src, files} inlist apps_files do
      target = File.join(path, "#{Relex.App.name(app)}-#{Relex.App.version(app)}")
      Relex.Files.copy(files, src, target)
    end
    :ok
  end

  def write_script!(release, options) do
    path = File.join([options[:path] || File.cwd!, release.name(options), "releases", release.version(options)])
    File.mkdir_p! path
    rel_file = File.join(path, "#{release.name(options)}.rel")
    File.write rel_file, :io_lib.format("~p.~n",[rel(release, options)])
    code_path = lc path inlist release.code_path(options), do: to_char_list(path)
    :systools.make_script(to_char_list(File.join(path, release.name(options))), [path: code_path, outdir: to_char_list(path)])
    if release.default_release?(options) and release.include_erts?(options) do
      lib_path = File.join([options[:path] || File.cwd!, release.name(options)])
      boot_file = "#{release.name(options)}.boot"
      boot = File.join([path, boot_file])
      erts_vsn = "erts-#{release.erts_version(options)}"      
      target = File.join([lib_path, erts_vsn, "bin"])
      File.cp!(boot, File.join([target, "start.boot"]))
    end
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
    apps = lc req inlist requirements, do: Relex.App.code_path(release.code_path(options), Relex.App.new(req))
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
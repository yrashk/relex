defmodule Relex.Release do
  @moduledoc """
  Defines a Relex release

  ### Example

      defmodule MyRelease do
        use Relex.Release

        def name, do: "my"
        def version, do: "1.0"
      end

  For more information, please refer to Relex.Release.Template
  """

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

      @moduledoc """

      This module defines a Relex release via a series of overridable
      callbacks.

      ### Example

          defmodule #{inspect __MODULE__} do
            use Relex.Release
    
            def name, do: "my"
            def version, do: "1.0"
          end

      Every callback takes N and N+1 arguments. What does that mean?

      Most of the time, you want to override the N version. For example:

          def name, do: "myrel"

      However, if you want to be able to pass some options to the callback
      through `assemble!/1`, you can use those options in the callback if
      you override the N+1 version which gets the config prepended prior to the rest of 
      the arguments:

          def name(config), do: config[:release_name]
      """

      def write_script!(apps, opts // []), do: write_script!(__MODULE__, apps, opts)
      def bundle!(kind, opts // []), do: bundle!(kind, __MODULE__, opts)

      @doc """
      Assembles a release. 

      ### Options:

      * path: path where the repository will be created, by default File.cwd!
      """
      def assemble!(opts // []) do
        apps = bundle!(:applications, opts)
        if include_erts?(opts), do: bundle!(:erts, opts)
        write_script!(apps, opts)        
        after_bundle(opts)
      end

      @doc """
      Release name, module name by default 
      """
      defcallback name, do: inspect(__MODULE__)

      @doc  """
      Release version, "1" by default
      """
      defcallback version, do: "1"

      @doc """
      Basic applications to include into the release. By default,
      it is kernel, stdlib and sasl.

      In most of cases, you don't want to remove neither kernel or stdlib. You can,
      however, remove sasl. Please note that removal of sasl will lead to inability
      to do release upgrades, as sasl includes release_handler module
      """
      defcallback basic_applications do
        [:kernel, :stdlib, :sasl]
      end

      @doc """
      List of applications to be included into the release. Empty by default.
      """
      defcallback applications do
        []
      end

      @doc """
      ERTS version to be used in the release. By default, current ERTS version.

      Please note that if you designate another version, it should be available in
      your root directory to be copied over into the release.
      """
      defcallback erts_version do
        list_to_binary(:erlang.system_info(:version))
      end

      @doc """
      List of ebin directories to look for beam files in. By default,
      it's `:code.get_path()` concatenated with directories defined in lib_dirs
      callback.

      Due to the somewhat complex nature of this callback, it is not
      advisable to override it without a good reason.
      """
      defcallback code_path do
        lc path inlist :code.get_path, do: list_to_binary(path)
      end
      def code_path(options) do
        ebins = List.flatten(lc path inlist lib_dirs(options) do
                               File.wildcard(File.join([File.expand_path(path),"**","ebin"]))
                             end)
        ebins ++ code_path
      end

      @doc """
      List of directories to look for applications in. Empty by default.

      A typical example would be `["deps"]`
      """
      defcallback lib_dirs, do: []

      @doc """
      Erlang's installation root directory. `:code.root_dir()` by default.

      Do not override it unless you have a good reason.
      """
      defcallback root_dir do
        list_to_binary(:code.root_dir)
      end

      @doc """
      This callback will be called everytime a decision on including an application is
      made. If it returns false, the application will be skipped. True by default.

      Please note that this behaviour can severely damaged release's ability to boot
      or even build.
      """
      defcallback include_application?(app), do: true

      @doc """
      This callback is used to filter out ERTS files to be copied.

      By default, it's bin/*, lib/*, include/* and info
      """
      defcallback include_erts_file?(file) do
        regexes = [%r"^bin(/.+)?$", %r"^lib(/.+)?$", %r"^include(/.+)?$", %r(^info$)]        
        Enum.any?(regexes, Regex.match?(&1, file))
      end

      @doc """
      This callback is used to filter out application files to be copied.

      By default, it's ebin/*, priv/* and include/*
      """
      defcallback include_app_file?(file) do
        regexes = [%r"^ebin(/.+)?$", %r"^priv(/.+)?$", %r"^include(/.+)?$"]
        Enum.any?(regexes, Regex.match?(&1, file))
      end

      @doc """
      Specifies whether ERTS should be included into the release. True by default.
      """
      defcallback include_erts?, do: true

      @doc """
      Specifies whether this release's boot file should be designated as a
      default "start" boot file. True by default.
      """
      defcallback default_release?, do: true

      @doc """
      Specifies whether scripts in erts should use current root directory (false)
      or use one in the release itself (true). True by default.
      """
      defcallback relocatable?, do: true

      def after_bundle(opts) do
        Relex.Helper.MinimalStarter.render(__MODULE__, opts)
      end

      defoverridable after_bundle: 1

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
      files = Relex.Files.files(src,
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
      files = Relex.Files.files(src,
                                fn(file) -> 
                                  release.include_app_file?(options, Relex.Files.relative_path(src, file)) 
                                end)
      {app, src, files}
    end
    lc {app, src, files} inlist apps_files do
      target = File.join(path, "#{Relex.App.name(app)}-#{Relex.App.version(app)}")
      Relex.Files.copy(files, src, target)
    end
    apps
  end

  def write_script!(release, apps, options) do
    path = File.join([options[:path] || File.cwd!, release.name(options), "releases", release.version(options)])
    File.mkdir_p! path
    rel_file = File.join(path, "#{release.name(options)}.rel")
    File.write rel_file, :io_lib.format("~p.~n",[rel(release, apps, options)])
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

  def rel(release, apps, options) do
    {:release, {to_char_list(release.name(options)), to_char_list(release.version(options))},
               {:erts, to_char_list(release.erts_version(options))},
               (lc app inlist apps do
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
    Enum.filter apps, fn(app) -> release.include_application?(options, app) end
  end

  defp deps(app) do
    deps = Relex.App.dependencies(app)
    deps = deps ++ (lc app inlist deps, do: deps(app))
    List.flatten(deps)
  end

  defmacro defcallback({callback_name, _, args}, opts) do
    if is_atom(args), do: args = []
    full_args = [(quote do: _config)|args]
    sz = length(args)
    quote do
      @cb_doc @doc
      def unquote(callback_name)(unquote_splicing(full_args)) do
        unquote(callback_name)(unquote_splicing(args))
      end
      @doc @cb_doc
      def unquote(callback_name)(unquote_splicing(args)), unquote(opts)
      Module.delete_attribute __MODULE__, :cb_doc
      defoverridable [{unquote(callback_name), unquote(sz)}, 
                      {unquote(callback_name), unquote(sz+1)}]
    end
  end

end

defmodule Relex.Release.Template do
  use Relex.Release
end


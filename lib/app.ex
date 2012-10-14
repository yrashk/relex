defrecord Relex.App, name: nil, version: nil, path: nil, app: nil, type: :permanent, code_path: [] do

  defexception NotFound, app: nil do
    def message(exc), do: "Application #{inspect app(exc)} not found"
  end  

  defoverridable new: 1, app: 1, path: 1, version: 1

  def new(atom) when is_atom(atom), do: new(name: atom)
  def new({name, options}) when is_atom(name) do
    new(Keyword.merge([name: name], options))
  end
  def new(opts), do: super(opts)

  def app(rec) do
    case rec do
      Relex.App[name: name, app: nil] ->
        {:ok, [app]} = :file.consult(File.join([path(rec),"ebin","#{name}.app"]))
        app
      Relex.App[app: app] ->
        app
    end
  end

  def path(rec) do
    case rec do
      Relex.App[version: version, name: name, code_path: code_path, path: nil] ->
        case :ets.lookup(__MODULE__, {:path, {name, version}}) do
          [{_, path}] -> path
          _ ->
            paths = code_path
            paths = Enum.filter(paths, fn(p) -> File.exists?(File.join([p, "#{name}.app"])) end)
            paths = lc path inlist paths, do: File.join(path, "..")
            result =
            case paths do
             [] -> raise NotFound, app: rec
             [path] -> 
               if version_matches?(version, path(path, rec)) do
                 path
               else
                 raise NotFound, app: rec
               end
             _ ->
               apps = 
               lc path inlist paths do
                 update([path: path], rec)
               end
               apps = Enum.filter(apps, fn(app) -> version_matches?(version, app) end)
               apps = List.sort(apps, fn(app1, app2) -> version(app2) <= version(app1) end)
               path(hd(apps))
            end
            :ets.insert(__MODULE__, {{:path, {name, version}}, result})
            result
        end
      Relex.App[path: path] ->
        path
    end
  end

  def version(rec) do
    keys(rec)[:vsn]
  end

  defp version_matches?(nil, _app), do: true
  defp version_matches?(version, app) do
    cond do
    is_record(version, Regex) ->
      Regex.match?(version, version(app))
    is_function(version, 1) ->
      version.(app)
    true ->
      to_binary(version(app)) == to_binary(version)
    end
  end

  def dependencies(rec) do
    (lc app inlist (keys(rec)[:applications] || []), do: code_path(code_path(rec), new(app))) ++
    included_applications(rec)
  end

  def included_applications(rec) do
    lc app inlist (keys(rec)[:included_applications] || []), do: code_path(code_path(rec), new(app))
  end

  defp keys(rec) do
    {:application, _, opts} = app(rec)
    Keyword.from_enum(opts)  
  end

end

defimpl Binary.Inspect, for: Relex.App do
  def inspect(Relex.App[name: name, version: version], _opts) do
    cond do
      is_record(version, Regex) ->
       version = inspect(version)
      is_function(version) ->
       version = "<version checked by #{inspect(version)}>"
      true ->
       :ok
    end       
    version = if nil?(version), do: "", else: "-#{version}"
    "#{name}#{version}"
  end
end
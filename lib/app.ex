defrecord Relex.App, name: nil, version: nil, path: nil, app: nil, type: :permanent do

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
        {:ok, [app]} = :file.consult(File.join([path(rec),"#{name}.app"]))
        app
      Relex.App[app: app] ->
        app
    end
  end

  def path(rec) do
    case rec do
      Relex.App[version: version, name: name,  path: nil] ->
        paths = lc path inlist :code.get_path, do: list_to_binary(path)
        paths = Enum.filter(paths, fn(p) -> File.exists?(File.join([p, "#{name}.app"])) end)
        case paths do
         [] -> raise NotFound, app: rec
         [path] -> path
         _ ->
           apps = 
           lc path inlist paths do
             app(update([path: path], rec))
           end
           unless nil?(version) do
             apps = Enum.filter(apps, fn(app) -> 
                                        if is_record(version, Regex) do
                                          Regex.match?(version(app), version)
                                        else
                                          version(app) == version 
                                        end
                                      end)
           end
           apps = List.sort(apps, fn(app1, app2) -> version(app2) <= version(app1) end)
           path(hd(apps))
        end
      Relex.App[path: path] ->
        path
    end
  end

  def version(rec) do
    keys(rec)[:vsn]
  end

  def dependencies(rec) do
    (lc app inlist (keys(rec)[:applications] || []), do: new(app)) ++
    included_applications(rec)
  end

  def included_applications(rec) do
    lc app inlist (keys(rec)[:included_applications] || []), do: new(app)
  end

  defp keys(rec) do
    {:application, _, opts} = app(rec)
    Keyword.from_enum(opts)  
  end

end
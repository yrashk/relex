defmodule Relex.Files do

  alias :file, as: F

  def files(directory, cb) do
    case F.list_dir(directory) do
      {:ok, files} ->
        files = lc file inlist files, do: Path.join(directory, to_string(file))
        files = Enum.filter(files, &cb.(&1))
        directories = Enum.filter(files, &File.dir?(&1))
        files = files -- directories
        files ++ List.flatten(lc dir inlist directories, do: files(dir, cb))
      other -> other
    end
  end

  def copy(files, src, dest) when is_list(files) do
    File.mkdir_p!(dest)
    copy_files(files, src, dest)
  end

  def relative_path(base, file) do
    split = Path.split(base)
    Path.join(:lists.nthtail(length(split), Path.split(file)))
  end

  defp copy_files([], _, _), do: :ok
  defp copy_files([file|files], src, dest) do
  rel_path = relative_path(src, file)
    dest_file = Path.join([dest, rel_path])
    if File.dir?(file) do
      File.mkdir_p(dest_file)
    else
      :filelib.ensure_dir(dest_file)
      File.cp!(file, dest_file)
    end
    copy_files(files, src, dest)
  end
end
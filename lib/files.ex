defmodule Relex.Files do

  def copy(files, src, dest) when is_list(files) do
    File.mkdir_p!(dest)
    copy_files(files, src, dest)
  end

  def relative_path(base, file) do
    split = File.split(base) 
    File.join(:lists.nthtail(length(split), File.split(file)))    
  end

  defp copy_files([], _, _), do: :ok
  defp copy_files([file|files], src, dest) do
  rel_path = relative_path(src, file)
    dest_file = File.join([dest, rel_path])    
    if File.dir?(file) do
      File.mkdir_p(dest_file)
    else
      :filelib.ensure_dir(dest_file)
      File.cp!(file, dest_file)
      stat = File.stat!(file)
      File.write_stat!(dest_file, stat)
    end
    copy_files(files, src, dest)
  end
end
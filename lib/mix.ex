defmodule Mix.Tasks.Relex do
  def release do
    project = Mix.project
    guess = Module.concat([Mix.Project.get, Release])
    release = project[:release] || guess
    unless Code.ensure_loaded?(release) do
      Mix.shell.error "No release defined, use :release property or define #{guess}"
    end
    options = project[:release_options] || []
    {release, options}
  end

  def release_info(release, options) do
    "#{release.name(options)}-#{release.version(options)}"  
  end
end

defmodule Mix.Tasks.Relex.Assemble do
  use Mix.Task

  @shortdoc "Assembles a release"

  def run(_args) do
    {release, options} = Mix.Tasks.Relex.release
    release_info = Mix.Tasks.Relex.release_info(release, options)
    Mix.shell.info "Assembling release #{release_info}"
    try do
      case release.assemble!(options) do
        :ok ->
          Mix.shell.info "Release #{release_info} has been assembled"
        error ->
          raise Relex.Error, message: inspect(error)
      end
    rescue e ->
        Mix.shell.error "Error during the assembly of #{release_info}"
        Mix.shell.error e.message
    end
  end
end

defmodule Mix.Tasks.Relex.Clean do
  use Mix.Task

  @shortdoc "Cleans the release"

  def run(_args) do
    {release, options} = Mix.Tasks.Relex.release
    path = File.expand_path(File.join(options[:path] || ".", release.name(options)))
    File.rm_rf! path
  end  
end

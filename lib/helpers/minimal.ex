defmodule Relex.Helper.MinimalStarter do

  def render(release, opts) do
    if release.include_erts?(opts) do
      path = File.expand_path(opts[:path] || File.cwd!)
      script_path = File.join([path, release.name, "bin", "start"])
      File.mkdir_p! File.dirname(script_path)
      File.write script_path, template(release: release, options: opts)
      stat = File.stat! script_path
      File.write_stat! script_path, File.Stat.mode(493, stat)
      if release.default_release?(opts) do
        release_path = File.join([opts[:path] || File.cwd!, release.name(opts), "releases", release.version(opts)])
        boot_file = "#{release.name(opts)}.boot"
        boot = File.join([release_path, boot_file])
        target = File.join([path, release.name, "bin"])
        File.cp!(boot, File.join([target, "start.boot"]))
      end
    end
  end

  require EEx  
  EEx.function_from_string :defp, :template, 
  %b|#! /bin/sh
DIR=$(cd ${0%/*} && pwd)/..
ERTS=$DIR/erts-<%= @release.erts_version %>
<%= if @release.relocatable?(@options) do %>
$ERTS/bin/erl
<% else %>
BINDIR=$ERTS/bin 
ROOTDIR=$DIR
export BINDIR
export ROOTDIR
$ERTS/bin/erlexec
<% end %>
|, [:assigns]

end
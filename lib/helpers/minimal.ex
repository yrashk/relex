defmodule Relex.Helper.MinimalStarter do

  def render(release, opts) do
    if release.include_erts?(opts) do
      path = File.expand_path(opts[:path] || File.cwd!)
      script_path = File.join([path, release.name, "bin", "start"])
      File.mkdir_p! File.dirname(script_path)
      File.write script_path, template(path: path, release: release)
      stat = File.stat! script_path
      File.write_stat! script_path, File.Stat.mode(493, stat)
    end
  end

  require EEx  
  EEx.function_from_string :defp, :template, 
  %b|#! /bin/sh
SELF=$(cd ${0%/*} && pwd)
cd $SELF/..
DIR="`pwd`"
ERTS=$DIR/lib/erts-<%= @release.erts_version %>
BINDIR=$ERTS/bin 
ROOTDIR=$DIR
export BINDIR
export ROOTDIR
$ERTS/bin/erlexec -boot $DIR/releases/<%= @release.version %>/<%= @release.name %>
|, [:assigns]

end
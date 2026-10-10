{ pkgs }:
pkgs.symlinkJoin {
  name = "appDependencies";
  paths = with pkgs; [
    postgresql
    inotify-tools
    vips
  ];
}

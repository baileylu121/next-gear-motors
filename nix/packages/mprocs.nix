{ pkgs, flake }:
pkgs.writeShellApplication {
  name = "mprocs";

  runtimeInputs = with pkgs; [
    mprocs
    beamPackages.elixir
    flake.packages.${system}.appDependencies
    flake.packages.${system}.docsWatch
    flake.packages.${system}.postgresDev
  ];

  text = ''
    exec mprocs \
      "mix phx.server" \
      "mix test.watch --stale" \
      "postgres-dev" \
      "docsWatch"
  '';
}

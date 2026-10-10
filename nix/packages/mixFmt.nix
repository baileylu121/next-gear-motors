{ pkgs }:
pkgs.writeShellApplication {
  name = "mix-fmt";

  runtimeInputs = with pkgs; [
    beamPackages.elixir
  ];

  text = ''
    exec mix "do" \
      app.config --no-deps-check --no-compile, \
      format
  '';
}

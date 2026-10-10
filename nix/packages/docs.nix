{
  pkgs,
  flake,
  system,
}:
let
  mixNixDeps = flake.lib.mixNixDeps pkgs;
in
pkgs.beamPackages.mixRelease {
  inherit mixNixDeps;

  pname = "docs";
  version = flake.lib.readMixVersion ../../mix.exs;

  src = flake;

  removeCookie = false;
  stripDebug = true;

  env = {
    DATABASE_URL = "postgres://localhost/next_gear_motors";
    SECRET_KEY_BASE = "build-time-placeholder";
  };

  nativeBuildInputs = [
    flake.packages.${system}.appDependencies
  ];

  buildPhase = ''
    mix do \
      app.config --no-deps-check --no-compile, \
      docs --warnings-as-errors
  '';

  installPhase = ''
    mkdir -p $out/lib/doc

    cp -r ./doc/. $out/lib/doc

    mkdir -p $out/bin
  '';
}

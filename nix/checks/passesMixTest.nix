{
  pkgs,
  flake,
  system,
  ...
}:
let
  mixNixDeps = flake.lib.mixNixDeps pkgs;
in
pkgs.beamPackages.mixRelease {
  inherit mixNixDeps;

  pname = "passes-mix-test";
  version = flake.lib.readMixVersion ../../mix.exs;

  src = flake.lib.nixSrc;

  env = {
    DATABASE_URL = "postgres://localhost/next_gear_motors";
    SECRET_KEY_BASE = "build-time-placeholder";
  };

  mixEnv = "test";

  nativeBuildInputs = [
    flake.packages.${system}.appDependencies
    flake.packages.${system}.postgresDev
  ];

  doCheck = true;
  checkPhase = ''
    postgres-dev &

    until pg_isready -h /tmp ; do sleep 1 ; done

    export HOME=$TMPDIR

    mix do \
      app.config --no-deps-check --no-compile, \
      credo, \
      sobelow, \
      deps.audit, \
      test --no-deps-check
  '';
}

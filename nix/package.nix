{
  pkgs,
  flake,
  system,
}:
let
  mixNixDeps = flake.lib.mixNixDeps pkgs;
in
pkgs.beamPackages.mixRelease rec {
  inherit mixNixDeps;

  pname = "next_gear_motors";
  version = flake.lib.readMixVersion (flake + "/mix.exs");

  src = flake;

  removeCookie = false;
  stripDebug = true;

  env = {
    DATABASE_URL = "postgres://localhost/next_gear_motors";
    SECRET_KEY_BASE = "build-time-placeholder";
  };

  nativeBuildInputs = with pkgs; [
    flake.packages.${system}.appDependencies
    nodejs
    npmHooks.npmConfigHook
    makeWrapper
  ];

  npmDeps = pkgs.fetchNpmDeps {
    inherit version;

    pname = "${pname}-npm-deps";
    src = (flake + "/assets");
    hash = "sha256-hDbD7f5TbL6UOeNRJo4YzdOBfC05fakFjO2mlLi9oBY=";
  };

  npmRoot = "./assets";
  makeCacheWritable = true;

  postBuild = ''
    tailwind_path="$(mix do \
      app.config --no-deps-check --no-compile + \
      eval 'Tailwind.bin_path() |> IO.puts()')"
    esbuild_path="$(mix do \
      app.config --no-deps-check --no-compile + \
      eval 'Esbuild.bin_path() |> IO.puts()')"

    ln -sfv ${pkgs.tailwindcss_4}/bin/tailwindcss "$tailwind_path"
    ln -sfv ${pkgs.esbuild}/bin/esbuild "$esbuild_path"
    ln -sfvn ${mixNixDeps.heroicons}/src deps/heroicons

    mix do \
      app.config --no-deps-check --no-compile + \
      assets.deploy --no-deps-check
  '';

  postInstall = ''
    wrapProgram $out/bin/next_gear_motors \
      --set PATH ${pkgs.lib.makeBinPath [ flake.packages.${system}.appDependencies ]}
  '';
}

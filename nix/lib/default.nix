{ inputs, flake, ... }:
let
  eachSystem = inputs.nixpkgs.lib.genAttrs (import inputs.systems);
  lib = inputs.nixpkgs.lib;
in
eachSystem (
  system:
  let
    pkgs = inputs.nixpkgs.legacyPackages.${system};
  in
  {
    treefmt = inputs.treefmt-nix.lib.evalModule pkgs (
      import ./treefmt-config.nix { inherit flake system; }
    );
  }
)
// {
  readMixVersion =
    mixExs:
    let
      text = builtins.readFile mixExs;
      matches = builtins.match ''^.*version: "(.*)".*$'' text;
    in
    assert lib.assertMsg (matches != null) "No match could be found for mix.exs version field";
    builtins.head matches;

  mixNixDeps =
    pkgs:
    pkgs.callPackages (flake + "/deps.nix") {
      overrides = _self: prev: {
        lazy_html =
          let
            fileName = "lazy_html-nif-2.16-${archive.target}-0.1.13.tar.gz";

            archives = {
              x86_64-linux = {
                target = "x86_64-linux-gnu";
                hash = "sha256-4LbnTj2ulV/sL4qqMGxTWZRUqkmJIQJKvSVcWapflps=";
              };
              aarch64-linux = {
                target = "aarch64-linux-gnu";
                hash = "sha256-rd5xDbYQkUOpwohOSsASaTojJOs63z/Bp3jH0SW/4eI=";
              };
              x86_64-darwin = {
                target = "x86_64-apple-darwin";
                hash = "sha256-hH5OuhtvRKPMiMK9UVKMPR/2uCM8nCKs1ZIPP+jWINM=";
              };
              aarch64-darwin = {
                target = "aarch64-apple-darwin";
                hash = "sha256-VjtzkTevkfUHj/eUslnluMJZE2x9vGPbVich2r4Xb+M=";
              };
            };

            archive = archives.${pkgs.stdenv.hostPlatform.system} or null;
          in
          prev.lazy_html.overrideAttrs (old: {
            preConfigure =
              (old.preConfigure or "")
              + lib.optionalString (archive != null) ''
                export ELIXIR_MAKE_CACHE_DIR="$TMPDIR/elixir_make_cache"
                mkdir -p "$ELIXIR_MAKE_CACHE_DIR"
                cp ${
                  pkgs.fetchurl {
                    url = "https://github.com/dashbitco/lazy_html/releases/download/v0.1.13/${fileName}";
                    inherit (archive) hash;
                  }
                } "$ELIXIR_MAKE_CACHE_DIR/${fileName}"
              '';
          });

        vix =
          let
            pkgConfigPath = pkgs.lib.makeSearchPath "lib/pkgconfig" [
              pkgs.vips.dev
              pkgs.glib.dev
            ];
          in
          prev.vix.overrideAttrs (old: {
            nativeBuildInputs = (old.nativeBuildInputs or [ ]) ++ [ pkgs.glib ];
            postPatch = ''
              substituteInPlace c_src/Makefile \
                --replace-fail \
                'VIPS_PKG_CONFIG := $(PKG_CONFIG)' \
                'VIPS_PKG_CONFIG := env PKG_CONFIG_PATH=${pkgConfigPath} $(PKG_CONFIG)'
            '';
          });
      };
    };
}

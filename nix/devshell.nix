{
  pkgs,
  flake,
  ...
}:
let
  install-deps = pkgs.writeShellApplication {
    name = "install-deps";
    text = ''
      root=$(git rev-parse --show-toplevel)
      cd "$root"

      mix deps.get
      mix compile

      tailwind_output="$(mix eval 'Tailwind.bin_path() |> IO.puts()')"
      tailwind_path="''${tailwind_output##*$'\n'}"
      ln -sfv "${pkgs.tailwindcss_4}/bin/tailwindcss" "$tailwind_path"

      cd ./assets
      npm install
    '';
  };
in
pkgs.mkShell {
  packages = with pkgs; [
    beamPackages.elixir
    nodejs
    watchman
    flyctl
    skopeo
    install-deps
    flake.packages.${system}.appDependencies
    flake.lib.${system}.treefmt.config.build.wrapper
  ];

  LD_LIBRARY_PATH = "${pkgs.stdenv.cc.cc.lib}/lib/:/run/opengl-driver/lib/";

  shellHook = ''
    sh -c install-deps
  '';
}

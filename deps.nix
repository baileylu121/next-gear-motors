{
  lib,
  beamPackages,
  extend,
  lexbor,
  fetchFromGitHub,
  overrides ? (_x: _y: { }),
  overrideFenixOverlay ? null,
  rustlerPrecompiledOverrides ? { },
  stdenv,
  pkg-config,
  vips,
}:

let
  buildMix = lib.makeOverridable beamPackages.buildMix;
  buildRebar3 = lib.makeOverridable beamPackages.buildRebar3;

  workarounds = {
    portCompiler = _unusedArgs: _old: {
      buildPlugins = [ beamPackages.pc ];
    };

    rustlerPrecompiled =
      {
        toolchain ? null,
        buildInputs ? [ ],
        nativeBuildInputs ? [ ],
        env ? { },
        ...
      }:
      old:
      let
        extendedPkgs = extend fenixOverlay;
        fenixOverlay =
          if overrideFenixOverlay == null then
            import "${
              fetchTarball {
                url = "https://github.com/nix-community/fenix/archive/6399553b7a300c77e7f07342904eb696a5b6bf9d.tar.gz";
                sha256 = "sha256-C6tT7K1Lx6VsYw1BY5S3OavtapUvEnDQtmQB5DSgbCc=";
              }
            }/overlay.nix"
          else
            overrideFenixOverlay;
        nativeDir = "${old.src}/native/${with builtins; head (attrNames (readDir "${old.src}/native"))}";
        fenix =
          if toolchain == null then
            extendedPkgs.fenix.stable
          else
            extendedPkgs.fenix.fromToolchainName toolchain;
        native =
          (
            (extendedPkgs.makeRustPlatform {
              inherit (fenix) cargo rustc;
            }).buildRustPackage
              {
                inherit env buildInputs;
                pname = "${old.beamModuleName}-native";
                version = old.version;
                src = nativeDir;
                cargoLock = {
                  lockFile = "${nativeDir}/Cargo.lock";
                };
                nativeBuildInputs = [ extendedPkgs.cmake ] ++ nativeBuildInputs;
                doCheck = false;
              }
          ).overrideAttrs
            rustlerPrecompiledOverrides.${old.beamModuleName} or { };

      in
      {
        nativeBuildInputs = [ extendedPkgs.cargo ];

        env.RUSTLER_PRECOMPILED_FORCE_BUILD_ALL = "true";
        env.RUSTLER_PRECOMPILED_GLOBAL_CACHE_PATH = "unused-but-required";

        preConfigure = ''
          mkdir -p priv/native
          for lib in ${native}/lib/*
          do
            dest="$(basename "$lib")"
            if [[ "''${dest##*.}" = "dylib" ]]
            then
              dest="''${dest%.dylib}.so"
            fi
            dest="''${dest#lib}"
            ln -s "$lib" "priv/native/$dest"
          done
        '';

        preBuild = ''
          suggestion() {
            echo "***********************************************"
            echo "                 deps_nix                      "
            echo
            echo " Rust dependency build failed.                 "
            echo
            echo " If you saw network errors, you might need     "
            echo " to disable compilation on the appropriate     "
            echo " RustlerPrecompiled module in your             "
            echo " application config.                           "
            echo
            echo " We think you need this:                       "
            echo
            echo -n " "
            grep -Rl 'use RustlerPrecompiled' lib \
              | xargs grep 'defmodule' \
              | sed 's/defmodule \(.*\) do/config :${old.beamModuleName}, \1, skip_compilation?: true/'
            echo "***********************************************"
            exit 1
          }
          trap suggestion ERR
        '';
      };

    elixirMake = _unusedArgs: _old: {
      preConfigure = ''
        export ELIXIR_MAKE_CACHE_DIR="$TEMPDIR/elixir_make_cache"
      '';
    };

    lazyHtml = _unusedArgs: _old: {
      preConfigure = ''
        export ELIXIR_MAKE_CACHE_DIR="$TEMPDIR/elixir_make_cache"
      '';

      postPatch = ''
        substituteInPlace mix.exs \
          --replace-fail "Fine.include_dir()" '"${packages.fine}/src/c_include"' \
          --replace-fail '@lexbor_git_sha "244b84956a6dc7eec293781d051354f351274c46"' '@lexbor_git_sha ""'
      '';

      preBuild = ''
        install -Dm644           -t _build/c/third_party/lexbor/$LEXBOR_GIT_SHA/build           ${lexbor}/lib/liblexbor_static.a
      '';
    };
  };

  defaultOverrides = (
    _final: prev:

    let
      apps = {
        crc32cer = [
          {
            name = "portCompiler";
          }
        ];
        explorer = [
          {
            name = "rustlerPrecompiled";
            toolchain = {
              name = "nightly-2025-06-23";
              sha256 = "sha256-UAoZcxg3iWtS+2n8TFNfANFt/GmkuOMDf7QAE0fRxeA=";
            };
          }
        ];
        snappyer = [
          {
            name = "portCompiler";
          }
        ];
      };

      applyOverrides =
        appName: drv:
        let
          allOverridesForApp = builtins.foldl' (
            acc: workaround: acc // (workarounds.${workaround.name} workaround) drv
          ) { } apps.${appName};

        in
        if builtins.hasAttr appName apps then drv.override allOverridesForApp else drv;

    in
    builtins.mapAttrs applyOverrides prev
  );

  self = packages // (defaultOverrides self packages) // (overrides self packages);

  packages =
    with beamPackages;
    with self;
    {

      argon2_elixir =
        let
          version = "4.1.3";
          drv = buildMix {
            inherit version;
            name = "argon2_elixir";
            appConfigPath = ./config;

            src = fetchHex {
              inherit version;
              pkg = "argon2_elixir";
              sha256 = "7c295b8d8e0eaf6f43641698f962526cdf87c6feb7d14bd21e599271b510608c";
            };

            beamDeps = [
              comeonin
              elixir_make
            ];
          };
        in
        drv.override (workarounds.elixirMake { } drv);

      bandit =
        let
          version = "1.12.5";
          drv = buildMix {
            inherit version;
            name = "bandit";
            appConfigPath = ./config;

            src = fetchHex {
              inherit version;
              pkg = "bandit";
              sha256 = "c5684ca062fa407cac115aec3256383f3e2ec9fdced7904d59cf5a7bb7ed6181";
            };

            beamDeps = [
              hpax
              plug
              telemetry
              thousand_island
              websock
            ];
          };
        in
        drv;

      bunt =
        let
          version = "1.0.0";
          drv = buildMix {
            inherit version;
            name = "bunt";
            appConfigPath = ./config;

            src = fetchHex {
              inherit version;
              pkg = "bunt";
              sha256 = "dc5f86aa08a5f6fa6b8096f0735c4e76d54ae5c9fa2c143e5a1fc7c1cd9bb6b5";
            };
          };
        in
        drv;

      cc_precompiler =
        let
          version = "0.1.11";
          drv = buildMix {
            inherit version;
            name = "cc_precompiler";
            appConfigPath = ./config;

            src = fetchHex {
              inherit version;
              pkg = "cc_precompiler";
              sha256 = "3427232caf0835f94680e5bcf082408a70b48ad68a5f5c0b02a3bea9f3a075b9";
            };

            beamDeps = [
              elixir_make
            ];
          };
        in
        drv.override (workarounds.elixirMake { } drv);

      certifi =
        let
          version = "2.17.0";
          drv = buildRebar3 {
            inherit version;
            name = "certifi";

            src = fetchHex {
              inherit version;
              pkg = "certifi";
              sha256 = "8122798a17f0293c80daada25d0f81c7f4d708c73fef782c7c9b1950e26e4d21";
            };
          };
        in
        drv;

      color =
        let
          version = "0.13.0";
          drv = buildMix {
            inherit version;
            name = "color";
            appConfigPath = ./config;

            src = fetchHex {
              inherit version;
              pkg = "color";
              sha256 = "de127946869931d418bac2d82dc29feae1a8f5f729f135922fbccf0059a58ab2";
            };

            beamDeps = [
              bandit
              plug
            ];
          };
        in
        drv;

      comeonin =
        let
          version = "5.5.1";
          drv = buildMix {
            inherit version;
            name = "comeonin";
            appConfigPath = ./config;

            src = fetchHex {
              inherit version;
              pkg = "comeonin";
              sha256 = "65aac8f19938145377cee73973f192c5645873dcf550a8a6b18187d17c13ccdb";
            };
          };
        in
        drv;

      credo =
        let
          version = "1.7.19";
          drv = buildMix {
            inherit version;
            name = "credo";
            appConfigPath = ./config;

            src = fetchHex {
              inherit version;
              pkg = "credo";
              sha256 = "2d8bc95d5a7bb99dd2613621d4f08c6a3575c3fd4b62e6a2b48a100352a557b8";
            };

            beamDeps = [
              bunt
              file_system
              jason
            ];
          };
        in
        drv;

      db_connection =
        let
          version = "2.10.2";
          drv = buildMix {
            inherit version;
            name = "db_connection";
            appConfigPath = ./config;

            src = fetchHex {
              inherit version;
              pkg = "db_connection";
              sha256 = "510b14482330f1af6490a2fa0efd8d4f1435d1529b165647df22ac0f2df0fa93";
            };

            beamDeps = [
              telemetry
            ];
          };
        in
        drv;

      decimal =
        let
          version = "3.1.1";
          drv = buildMix {
            inherit version;
            name = "decimal";
            appConfigPath = ./config;

            src = fetchHex {
              inherit version;
              pkg = "decimal";
              sha256 = "c5f25f2ced74a0587d03e6023f595db8e924c9d3922c8c8ffd9edfc4498cf1f6";
            };
          };
        in
        drv;

      deps_nix =
        let
          version = "3.1.1";
          drv = buildMix {
            inherit version;
            name = "deps_nix";
            appConfigPath = ./config;

            src = fetchHex {
              inherit version;
              pkg = "deps_nix";
              sha256 = "8264b699341e7f7c90e8ccda70c7730ce524ad1e5ee7102992eff5b7fb2373ea";
            };

            beamDeps = [
              ex_nar
              mint
            ];
          };
        in
        drv;

      dns_cluster =
        let
          version = "0.3.1";
          drv = buildMix {
            inherit version;
            name = "dns_cluster";
            appConfigPath = ./config;

            src = fetchHex {
              inherit version;
              pkg = "dns_cluster";
              sha256 = "afa60bbbd84463e977eeeecc0c564d8c5ddea260beccdb8d5f45cbb860846627";
            };
          };
        in
        drv;

      earmark_parser =
        let
          version = "1.4.46";
          drv = buildMix {
            inherit version;
            name = "earmark_parser";
            appConfigPath = ./config;

            src = fetchHex {
              inherit version;
              pkg = "earmark_parser";
              sha256 = "9c44636e8a1c68c62f526b2dcd85d941dbbcee7ab82cf64ba06ce28bef8e89f5";
            };
          };
        in
        drv;

      ecto =
        let
          version = "3.14.2";
          drv = buildMix {
            inherit version;
            name = "ecto";
            appConfigPath = ./config;

            src = fetchHex {
              inherit version;
              pkg = "ecto";
              sha256 = "25d60b8c816a07d19d85b80bdf60978bd8b102209dda198d768cd7c6745339a6";
            };

            beamDeps = [
              decimal
              jason
              telemetry
            ];
          };
        in
        drv;

      ecto_psql_extras =
        let
          version = "0.8.8";
          drv = buildMix {
            inherit version;
            name = "ecto_psql_extras";
            appConfigPath = ./config;

            src = fetchHex {
              inherit version;
              pkg = "ecto_psql_extras";
              sha256 = "04c63d92b141723ad6fed2e60a4b461ca00b3594d16df47bbc48f1f4534f2c49";
            };

            beamDeps = [
              ecto_sql
              postgrex
              table_rex
            ];
          };
        in
        drv;

      ecto_sql =
        let
          version = "3.14.0";
          drv = buildMix {
            inherit version;
            name = "ecto_sql";
            appConfigPath = ./config;

            src = fetchHex {
              inherit version;
              pkg = "ecto_sql";
              sha256 = "f4d8d36faf294c9417b5a37ec7ac8217ee2abdef5fcf197ba690f361548d3949";
            };

            beamDeps = [
              db_connection
              decimal
              ecto
              postgrex
              telemetry
            ];
          };
        in
        drv;

      elixir_make =
        let
          version = "0.10.0";
          drv = buildMix {
            inherit version;
            name = "elixir_make";
            appConfigPath = ./config;

            src = fetchHex {
              inherit version;
              pkg = "elixir_make";
              sha256 = "dc1f09fb7fa68866b886abd5f0f3c83553b1a19a52359a899e92af1bb3b31982";
            };
          };
        in
        drv;

      esbuild =
        let
          version = "0.10.0";
          drv = buildMix {
            inherit version;
            name = "esbuild";
            appConfigPath = ./config;

            src = fetchHex {
              inherit version;
              pkg = "esbuild";
              sha256 = "468489cda427b974a7cc9f03ace55368a83e1a7be12fba7e30969af78e5f8c70";
            };

            beamDeps = [
              jason
            ];
          };
        in
        drv;

      ex_aws =
        let
          version = "2.7.0";
          drv = buildMix {
            inherit version;
            name = "ex_aws";
            appConfigPath = ./config;

            src = fetchHex {
              inherit version;
              pkg = "ex_aws";
              sha256 = "bfe9d744d4fd4c1f40314ee7fab504d5547d1f01cd377fff1568cbe630b06d65";
            };

            beamDeps = [
              hackney
              jason
              mime
              sweet_xml
              telemetry
            ];
          };
        in
        drv;

      ex_aws_s3 =
        let
          version = "2.5.9";
          drv = buildMix {
            inherit version;
            name = "ex_aws_s3";
            appConfigPath = ./config;

            src = fetchHex {
              inherit version;
              pkg = "ex_aws_s3";
              sha256 = "a480d2bb2da64610014021629800e1e9457ca5e4a62f6775bffd963360c2bf90";
            };

            beamDeps = [
              ex_aws
              sweet_xml
            ];
          };
        in
        drv;

      ex_doc =
        let
          version = "0.40.4";
          drv = buildMix {
            inherit version;
            name = "ex_doc";
            appConfigPath = ./config;

            src = fetchHex {
              inherit version;
              pkg = "ex_doc";
              sha256 = "6222b9e423d76584ee34df2c82a5ed72c2d53dc153f7f483ad28b378694186cc";
            };

            beamDeps = [
              earmark_parser
              makeup_elixir
              makeup_erlang
            ];
          };
        in
        drv;

      ex_nar =
        let
          version = "0.3.0";
          drv = buildMix {
            inherit version;
            name = "ex_nar";
            appConfigPath = ./config;

            src = fetchHex {
              inherit version;
              pkg = "ex_nar";
              sha256 = "cbb42d047764feac6c411efddcadc31866e9a998dd6e2bc1eb428cec1c49fdcd";
            };
          };
        in
        drv;

      expo =
        let
          version = "1.1.1";
          drv = buildMix {
            inherit version;
            name = "expo";
            appConfigPath = ./config;

            src = fetchHex {
              inherit version;
              pkg = "expo";
              sha256 = "5fb308b9cb359ae200b7e23d37c76978673aa1b06e2b3075d814ce12c5811640";
            };
          };
        in
        drv;

      file_system =
        let
          version = "1.1.1";
          drv = buildMix {
            inherit version;
            name = "file_system";
            appConfigPath = ./config;

            src = fetchHex {
              inherit version;
              pkg = "file_system";
              sha256 = "7a15ff97dfe526aeefb090a7a9d3d03aa907e100e262a0f8f7746b78f8f87a5d";
            };
          };
        in
        drv;

      finch =
        let
          version = "0.24.0";
          drv = buildMix {
            inherit version;
            name = "finch";
            appConfigPath = ./config;

            src = fetchHex {
              inherit version;
              pkg = "finch";
              sha256 = "33ba40069c3587c2f99f9125b766e19dad87d6d54be3c6961db2304df04cef00";
            };

            beamDeps = [
              mime
              mint
              nimble_options
              nimble_pool
              telemetry
            ];
          };
        in
        drv;

      fine =
        let
          version = "0.1.6";
          drv = buildMix {
            inherit version;
            name = "fine";
            appConfigPath = ./config;

            src = fetchHex {
              inherit version;
              pkg = "fine";
              sha256 = "5638eb4495488e885ebec167fa57973e5c35e1a50c344eb7666c90ec1c4e3b12";
            };
          };
        in
        drv;

      floki =
        let
          version = "0.38.4";
          drv = buildMix {
            inherit version;
            name = "floki";
            appConfigPath = ./config;

            src = fetchHex {
              inherit version;
              pkg = "floki";
              sha256 = "bdb34645eee8e79845c7edaca2d4099a52804ee4d4a3ecc683a69451f0244973";
            };
          };
        in
        drv;

      flop =
        let
          version = "0.29.0";
          drv = buildMix {
            inherit version;
            name = "flop";
            appConfigPath = ./config;

            src = fetchHex {
              inherit version;
              pkg = "flop";
              sha256 = "44dfcb21fad277122d1536d08d4550a4ec2d8476a2b2f54dcf8ab33fe165e356";
            };

            beamDeps = [
              ecto
              nimble_options
            ];
          };
        in
        drv;

      gettext =
        let
          version = "1.0.2";
          drv = buildMix {
            inherit version;
            name = "gettext";
            appConfigPath = ./config;

            src = fetchHex {
              inherit version;
              pkg = "gettext";
              sha256 = "eab805501886802071ad290714515c8c4a17196ea76e5afc9d06ca85fb1bfeb3";
            };

            beamDeps = [
              expo
            ];
          };
        in
        drv;

      h2 =
        let
          version = "0.12.4";
          drv = buildRebar3 {
            inherit version;
            name = "h2";

            src = fetchHex {
              inherit version;
              pkg = "h2";
              sha256 = "238553579d2599e823f1f7b1cacb763362ee6e2df8e8f3b0c8fc67da982c0675";
            };
          };
        in
        drv;

      hackney =
        let
          version = "4.8.5";
          drv = buildRebar3 {
            inherit version;
            name = "hackney";

            src = fetchHex {
              inherit version;
              pkg = "hackney";
              sha256 = "d1c18324ce5eaa5e45a245f31e68d212c4f3f24ee0a27e4eac09c5959831c138";
            };

            beamDeps = [
              certifi
              h2
              idna
              mimerl
              parse_trans
              quic
              ssl_verify_fun
              webtransport
            ];
          };
        in
        drv;

      heroicons = stdenv.mkDerivation {
        name = "heroicons";
        src = fetchFromGitHub {
          owner = "tailwindlabs";
          repo = "heroicons";
          rev = "88ab3a0d790e6a47404cba02800a6b25d2afae50";
          hash = "sha256-4yRqfY8r2Ar9Fr45ikD/8jK+H3g4veEHfXa9BorLxXg=";
        };
        buildPhase = ''
          mkdir $out
          ln -sv $src $out/src
        '';
      };

      hpax =
        let
          version = "1.1.0";
          drv = buildMix {
            inherit version;
            name = "hpax";
            appConfigPath = ./config;

            src = fetchHex {
              inherit version;
              pkg = "hpax";
              sha256 = "0b8d0f05832f55571d65ac720f79bf8994138ffbb133209dc4685eae0ad456a8";
            };
          };
        in
        drv;

      idna =
        let
          version = "7.1.0";
          drv = buildRebar3 {
            inherit version;
            name = "idna";

            src = fetchHex {
              inherit version;
              pkg = "idna";
              sha256 = "6ae959a025bf36df61a8cab8508d9654891b5426a84c44d82deaffd6ddf8c71f";
            };
          };
        in
        drv;

      image =
        let
          version = "0.72.0";
          drv = buildMix {
            inherit version;
            name = "image";
            appConfigPath = ./config;

            src = fetchHex {
              inherit version;
              pkg = "image";
              sha256 = "d55a6c3c90fe76e96265b655d85d6f2fafc439f66c6e792a4925f2d84378f3b0";
            };

            beamDeps = [
              color
              phoenix_html
              plug
              sweet_xml
              vix
            ];
          };
        in
        drv;

      jason =
        let
          version = "1.4.5";
          drv = buildMix {
            inherit version;
            name = "jason";
            appConfigPath = ./config;

            src = fetchHex {
              inherit version;
              pkg = "jason";
              sha256 = "b0c823996102bcd0239b3c2444eb00409b72f6a140c1950bc8b457d836b30684";
            };

            beamDeps = [
              decimal
            ];
          };
        in
        drv;

      lazy_html =
        let
          version = "0.1.13";
          drv = buildMix {
            inherit version;
            name = "lazy_html";
            appConfigPath = ./config;

            nativeBuildInputs = [
              lexbor
            ];

            src = fetchHex {
              inherit version;
              pkg = "lazy_html";
              sha256 = "9a8405d6785fe6f8423b86e0ec5f21806ef79941fe853eac3d14fbbb173c34e9";
            };

            beamDeps = [
              cc_precompiler
              elixir_make
              fine
            ];
          };
        in
        drv.override (workarounds.lazyHtml { } drv);

      mail =
        let
          version = "0.5.2";
          drv = buildMix {
            inherit version;
            name = "mail";
            appConfigPath = ./config;

            src = fetchHex {
              inherit version;
              pkg = "mail";
              sha256 = "f8e07c252d82528d8111c56707b51b44e8fa899cc05583ce282055b8c27a684c";
            };
          };
        in
        drv;

      makeup =
        let
          version = "1.2.3";
          drv = buildMix {
            inherit version;
            name = "makeup";
            appConfigPath = ./config;

            src = fetchHex {
              inherit version;
              pkg = "makeup";
              sha256 = "15970751b7021c2bcd7ed56a54b3def23affd3969fb7c214dffdf28e97ce6f76";
            };

            beamDeps = [
              nimble_parsec
            ];
          };
        in
        drv;

      makeup_elixir =
        let
          version = "1.0.1";
          drv = buildMix {
            inherit version;
            name = "makeup_elixir";
            appConfigPath = ./config;

            src = fetchHex {
              inherit version;
              pkg = "makeup_elixir";
              sha256 = "7284900d412a3e5cfd97fdaed4f5ed389b8f2b4cb49efc0eb3bd10e2febf9507";
            };

            beamDeps = [
              makeup
              nimble_parsec
            ];
          };
        in
        drv;

      makeup_erlang =
        let
          version = "1.1.0";
          drv = buildMix {
            inherit version;
            name = "makeup_erlang";
            appConfigPath = ./config;

            src = fetchHex {
              inherit version;
              pkg = "makeup_erlang";
              sha256 = "1cd6780fb1dd1a03979abaed0fe82712b0625118fd5257d3ebbf73f960c73c3c";
            };

            beamDeps = [
              makeup
            ];
          };
        in
        drv;

      mime =
        let
          version = "2.0.7";
          drv = buildMix {
            inherit version;
            name = "mime";
            appConfigPath = ./config;

            src = fetchHex {
              inherit version;
              pkg = "mime";
              sha256 = "6171188e399ee16023ffc5b76ce445eb6d9672e2e241d2df6050f3c771e80ccd";
            };
          };
        in
        drv;

      mimerl =
        let
          version = "1.5.0";
          drv = buildRebar3 {
            inherit version;
            name = "mimerl";

            src = fetchHex {
              inherit version;
              pkg = "mimerl";
              sha256 = "db648ce065bae14ea84ca8b5dd123f42f49417cef693541110bf6f9e9be9ecc4";
            };
          };
        in
        drv;

      mint =
        let
          version = "1.11.0";
          drv = buildMix {
            inherit version;
            name = "mint";
            appConfigPath = ./config;

            src = fetchHex {
              inherit version;
              pkg = "mint";
              sha256 = "c6279ba2d6aa3a383a1d4cfbe7b59f42e6efd400f58d8e2acfeac48a438693ab";
            };

            beamDeps = [
              hpax
            ];
          };
        in
        drv;

      mix_audit =
        let
          version = "2.1.5";
          drv = buildMix {
            inherit version;
            name = "mix_audit";
            appConfigPath = ./config;

            src = fetchHex {
              inherit version;
              pkg = "mix_audit";
              sha256 = "87f9298e21da32f697af535475860dc1d3617a010e0b418d2ec6142bc8b42d69";
            };

            beamDeps = [
              jason
              yaml_elixir
            ];
          };
        in
        drv;

      mix_test_watch =
        let
          version = "1.4.0";
          drv = buildMix {
            inherit version;
            name = "mix_test_watch";
            appConfigPath = ./config;

            src = fetchHex {
              inherit version;
              pkg = "mix_test_watch";
              sha256 = "2b4693e17c8ead2ef56d4f48a0329891e8c2d0d73752c0f09272a2b17dc38d1b";
            };

            beamDeps = [
              file_system
            ];
          };
        in
        drv;

      mogrify =
        let
          version = "0.9.3";
          drv = buildMix {
            inherit version;
            name = "mogrify";
            appConfigPath = ./config;

            src = fetchHex {
              inherit version;
              pkg = "mogrify";
              sha256 = "0189b1e1de27455f2b9ae8cf88239cefd23d38de9276eb5add7159aea51731e6";
            };
          };
        in
        drv;

      mua =
        let
          version = "0.2.6";
          drv = buildMix {
            inherit version;
            name = "mua";
            appConfigPath = ./config;

            src = fetchHex {
              inherit version;
              pkg = "mua";
              sha256 = "c8bd1417dc18208eed3a3e0f1b847930e7b649e3e71165d2934f3b1ba62b3c18";
            };
          };
        in
        drv;

      nimble_options =
        let
          version = "1.1.1";
          drv = buildMix {
            inherit version;
            name = "nimble_options";
            appConfigPath = ./config;

            src = fetchHex {
              inherit version;
              pkg = "nimble_options";
              sha256 = "821b2470ca9442c4b6984882fe9bb0389371b8ddec4d45a9504f00a66f650b44";
            };
          };
        in
        drv;

      nimble_parsec =
        let
          version = "1.4.2";
          drv = buildMix {
            inherit version;
            name = "nimble_parsec";
            appConfigPath = ./config;

            src = fetchHex {
              inherit version;
              pkg = "nimble_parsec";
              sha256 = "4b21398942dda052b403bbe1da991ccd03a053668d147d53fb8c4e0efe09c973";
            };
          };
        in
        drv;

      nimble_pool =
        let
          version = "1.1.0";
          drv = buildMix {
            inherit version;
            name = "nimble_pool";
            appConfigPath = ./config;

            src = fetchHex {
              inherit version;
              pkg = "nimble_pool";
              sha256 = "af2e4e6b34197db81f7aad230c1118eac993acc0dae6bc83bac0126d4ae0813a";
            };
          };
        in
        drv;

      parse_trans =
        let
          version = "3.4.2";
          drv = buildRebar3 {
            inherit version;
            name = "parse_trans";

            src = fetchHex {
              inherit version;
              pkg = "parse_trans";
              sha256 = "4c25347de3b7c35732d32e69ab43d1ceee0beae3f3b3ade1b59cbd3dd224d9ca";
            };
          };
        in
        drv;

      phoenix =
        let
          version = "1.8.15";
          drv = buildMix {
            inherit version;
            name = "phoenix";
            appConfigPath = ./config;

            src = fetchHex {
              inherit version;
              pkg = "phoenix";
              sha256 = "7b83ed6b3d544f24a29277eab7f051be38b76f390bb511bb6ddb7ec6e8e05b95";
            };

            beamDeps = [
              bandit
              jason
              phoenix_pubsub
              phoenix_template
              plug
              plug_crypto
              telemetry
              websock_adapter
            ];
          };
        in
        drv;

      phoenix_ecto =
        let
          version = "4.7.0";
          drv = buildMix {
            inherit version;
            name = "phoenix_ecto";
            appConfigPath = ./config;

            src = fetchHex {
              inherit version;
              pkg = "phoenix_ecto";
              sha256 = "1d75011e4254cb4ddf823e81823a9629559a1be93b4321a6a5f11a5306fbf4cc";
            };

            beamDeps = [
              ecto
              phoenix_html
              plug
              postgrex
            ];
          };
        in
        drv;

      phoenix_html =
        let
          version = "4.3.0";
          drv = buildMix {
            inherit version;
            name = "phoenix_html";
            appConfigPath = ./config;

            src = fetchHex {
              inherit version;
              pkg = "phoenix_html";
              sha256 = "3eaa290a78bab0f075f791a46a981bbe769d94bc776869f4f3063a14f30497ad";
            };
          };
        in
        drv;

      phoenix_live_dashboard =
        let
          version = "0.9.1";
          drv = buildMix {
            inherit version;
            name = "phoenix_live_dashboard";
            appConfigPath = ./config;

            src = fetchHex {
              inherit version;
              pkg = "phoenix_live_dashboard";
              sha256 = "de25e1a28cfb64413d8bdaf3ba5b64da1a19e0ed44a02320119523cc45da051d";
            };

            beamDeps = [
              ecto
              ecto_psql_extras
              mime
              phoenix_live_view
              telemetry_metrics
            ];
          };
        in
        drv;

      phoenix_live_reload =
        let
          version = "1.7.0";
          drv = buildMix {
            inherit version;
            name = "phoenix_live_reload";
            appConfigPath = ./config;

            src = fetchHex {
              inherit version;
              pkg = "phoenix_live_reload";
              sha256 = "dc9f44271aa6fc4ab7797f2aa374ba096ef2c87520586280eb095626b7387a68";
            };

            beamDeps = [
              file_system
              phoenix
            ];
          };
        in
        drv;

      phoenix_live_view =
        let
          version = "1.2.12";
          drv = buildMix {
            inherit version;
            name = "phoenix_live_view";
            appConfigPath = ./config;

            src = fetchHex {
              inherit version;
              pkg = "phoenix_live_view";
              sha256 = "656810d716e3369545dd63981196a5d68b77fdb253afe02ef0c6fa14cfd8dc2b";
            };

            beamDeps = [
              jason
              lazy_html
              phoenix
              phoenix_html
              phoenix_template
              plug
              telemetry
            ];
          };
        in
        drv;

      phoenix_pubsub =
        let
          version = "2.4.1";
          drv = buildMix {
            inherit version;
            name = "phoenix_pubsub";
            appConfigPath = ./config;

            src = fetchHex {
              inherit version;
              pkg = "phoenix_pubsub";
              sha256 = "352fba7a87bf61395b6e97da66944ad9b1bfe5459e5981039f60d68270bd9700";
            };
          };
        in
        drv;

      phoenix_template =
        let
          version = "1.1.0";
          drv = buildMix {
            inherit version;
            name = "phoenix_template";
            appConfigPath = ./config;

            src = fetchHex {
              inherit version;
              pkg = "phoenix_template";
              sha256 = "eba70070de79b2c3501ef205a74a69f98ab352f3785aa15da9ed161f9fe0fd5d";
            };

            beamDeps = [
              phoenix_html
            ];
          };
        in
        drv;

      plug =
        let
          version = "1.20.3";
          drv = buildMix {
            inherit version;
            name = "plug";
            appConfigPath = ./config;

            src = fetchHex {
              inherit version;
              pkg = "plug";
              sha256 = "be266aee1b8536ef6409d58cf39a3121319f0ec47cfa1b24024485aa0e76ad76";
            };

            beamDeps = [
              mime
              plug_crypto
              telemetry
            ];
          };
        in
        drv;

      plug_crypto =
        let
          version = "2.2.0";
          drv = buildMix {
            inherit version;
            name = "plug_crypto";
            appConfigPath = ./config;

            src = fetchHex {
              inherit version;
              pkg = "plug_crypto";
              sha256 = "83a95744ab1c75876542b6fab135fcc176280e0f301a111c1f757fddcec95d2c";
            };
          };
        in
        drv;

      postgrex =
        let
          version = "0.22.4";
          drv = buildMix {
            inherit version;
            name = "postgrex";
            appConfigPath = ./config;

            src = fetchHex {
              inherit version;
              pkg = "postgrex";
              sha256 = "4aae45a2d60e35b04eea2602440be152fae332901f1fc7a60fc7cb7f0f9a9c5a";
            };

            beamDeps = [
              db_connection
              decimal
              jason
            ];
          };
        in
        drv;

      quic =
        let
          version = "2.1.1";
          drv = buildRebar3 {
            inherit version;
            name = "quic";

            src = fetchHex {
              inherit version;
              pkg = "quic";
              sha256 = "305d78a857298d940f6621a9acd7391c02980555d5e7fffef364eccd330fd64d";
            };
          };
        in
        drv;

      sobelow =
        let
          version = "0.16.0";
          drv = buildMix {
            inherit version;
            name = "sobelow";
            appConfigPath = ./config;

            src = fetchHex {
              inherit version;
              pkg = "sobelow";
              sha256 = "00a0260edf9aeac35d9116366f55dc9451d11e0e696e28ec5570c6a56bd41f1e";
            };

            beamDeps = [
              jason
            ];
          };
        in
        drv;

      ssl_verify_fun =
        let
          version = "1.1.7";
          drv = buildMix {
            inherit version;
            name = "ssl_verify_fun";
            appConfigPath = ./config;

            src = fetchHex {
              inherit version;
              pkg = "ssl_verify_fun";
              sha256 = "fe4c190e8f37401d30167c8c405eda19469f34577987c76dde613e838bbc67f8";
            };
          };
        in
        drv;

      stream_data =
        let
          version = "1.4.0";
          drv = buildMix {
            inherit version;
            name = "stream_data";
            appConfigPath = ./config;

            src = fetchHex {
              inherit version;
              pkg = "stream_data";
              sha256 = "2b0ee3a340dcce1c8cf6302a763ee757d1e01c54d6e16d9069062509d68b1dc9";
            };
          };
        in
        drv;

      sweet_xml =
        let
          version = "0.7.5";
          drv = buildMix {
            inherit version;
            name = "sweet_xml";
            appConfigPath = ./config;

            src = fetchHex {
              inherit version;
              pkg = "sweet_xml";
              sha256 = "193b28a9b12891cae351d81a0cead165ffe67df1b73fe5866d10629f4faefb12";
            };
          };
        in
        drv;

      swoosh =
        let
          version = "1.29.0";
          drv = buildMix {
            inherit version;
            name = "swoosh";
            appConfigPath = ./config;

            src = fetchHex {
              inherit version;
              pkg = "swoosh";
              sha256 = "d23ea419c6c67604628c0e93a8d5c6d13bcc442137870671e1b05325b2956a13";
            };

            beamDeps = [
              bandit
              ex_aws
              finch
              hackney
              idna
              jason
              mail
              mime
              mua
              plug
              telemetry
            ];
          };
        in
        drv;

      table_rex =
        let
          version = "4.1.0";
          drv = buildMix {
            inherit version;
            name = "table_rex";
            appConfigPath = ./config;

            src = fetchHex {
              inherit version;
              pkg = "table_rex";
              sha256 = "95932701df195d43bc2d1c6531178fc8338aa8f38c80f098504d529c43bc2601";
            };
          };
        in
        drv;

      tailwind =
        let
          version = "0.5.1";
          drv = buildMix {
            inherit version;
            name = "tailwind";
            appConfigPath = ./config;

            src = fetchHex {
              inherit version;
              pkg = "tailwind";
              sha256 = "c4e26302a59fec72abc5610ecb6ad2116d9aa31f31aab2d4b8eb6e95d25a689c";
            };
          };
        in
        drv;

      telemetry =
        let
          version = "1.4.2";
          drv = buildRebar3 {
            inherit version;
            name = "telemetry";

            src = fetchHex {
              inherit version;
              pkg = "telemetry";
              sha256 = "928f6495066506077862c0d1646609eed891a4326bee3126ba54b60af61febb1";
            };
          };
        in
        drv;

      telemetry_metrics =
        let
          version = "1.2.0";
          drv = buildMix {
            inherit version;
            name = "telemetry_metrics";
            appConfigPath = ./config;

            src = fetchHex {
              inherit version;
              pkg = "telemetry_metrics";
              sha256 = "71dde12fc29b58b9c77ec17ec319109e5ca848d010fc1965ed4463bba1837c07";
            };

            beamDeps = [
              telemetry
            ];
          };
        in
        drv;

      telemetry_poller =
        let
          version = "1.3.0";
          drv = buildRebar3 {
            inherit version;
            name = "telemetry_poller";

            src = fetchHex {
              inherit version;
              pkg = "telemetry_poller";
              sha256 = "51f18bed7128544a50f75897db9974436ea9bfba560420b646af27a9a9b35211";
            };

            beamDeps = [
              telemetry
            ];
          };
        in
        drv;

      thousand_island =
        let
          version = "1.5.0";
          drv = buildMix {
            inherit version;
            name = "thousand_island";
            appConfigPath = ./config;

            src = fetchHex {
              inherit version;
              pkg = "thousand_island";
              sha256 = "708923d40523e43cf99041ab37a0d4b0ec426ac6438fa3716ab23d919eaeb412";
            };

            beamDeps = [
              telemetry
            ];
          };
        in
        drv;

      vix =
        let
          version = "0.42.0";
          drv = buildMix {
            inherit version;
            name = "vix";
            appConfigPath = ./config;

            env.VIX_COMPILATION_MODE = "PLATFORM_PROVIDED_LIBVIPS";

            nativeBuildInputs = [
              pkg-config
              vips
            ];

            src = fetchHex {
              inherit version;
              pkg = "vix";
              sha256 = "c4c92051653859dc5219f553a93fa777d63525ee961c48e16e9f61fed02472ee";
            };

            beamDeps = [
              cc_precompiler
              elixir_make
            ];
          };
        in
        drv.override (workarounds.elixirMake { } drv);

      waffle =
        let
          version = "2.0.0";
          drv = buildMix {
            inherit version;
            name = "waffle";
            appConfigPath = ./config;

            src = fetchHex {
              inherit version;
              pkg = "waffle";
              sha256 = "6196807c2e2502f41f9ae75b1907920993fe184089279088ca4682830a689c4a";
            };

            beamDeps = [
              ex_aws
              ex_aws_s3
              sweet_xml
            ];
          };
        in
        drv;

      waffle_ecto =
        let
          version = "0.0.13";
          drv = buildMix {
            inherit version;
            name = "waffle_ecto";
            appConfigPath = ./config;

            src = fetchHex {
              inherit version;
              pkg = "waffle_ecto";
              sha256 = "5b282325079fd056c177dee11123fe1241eef1a683f098805af8e02e20c31411";
            };

            beamDeps = [
              ecto
              waffle
            ];
          };
        in
        drv;

      websock =
        let
          version = "0.5.3";
          drv = buildMix {
            inherit version;
            name = "websock";
            appConfigPath = ./config;

            src = fetchHex {
              inherit version;
              pkg = "websock";
              sha256 = "6105453d7fac22c712ad66fab1d45abdf049868f253cf719b625151460b8b453";
            };
          };
        in
        drv;

      websock_adapter =
        let
          version = "0.6.0";
          drv = buildMix {
            inherit version;
            name = "websock_adapter";
            appConfigPath = ./config;

            src = fetchHex {
              inherit version;
              pkg = "websock_adapter";
              sha256 = "50021a85bce8f203b086705d9e0c5415e2c7eb05d319111b0428fe71f9934617";
            };

            beamDeps = [
              bandit
              plug
              websock
            ];
          };
        in
        drv;

      webtransport =
        let
          version = "0.4.8";
          drv = buildRebar3 {
            inherit version;
            name = "webtransport";

            src = fetchHex {
              inherit version;
              pkg = "webtransport";
              sha256 = "08477a2195ccbf944da0b78f85dc4e6ee4498790e3dd7fe84ee7a245938e1b26";
            };

            beamDeps = [
              h2
              quic
            ];
          };
        in
        drv;

      yamerl =
        let
          version = "0.10.0";
          drv = buildRebar3 {
            inherit version;
            name = "yamerl";

            src = fetchHex {
              inherit version;
              pkg = "yamerl";
              sha256 = "346adb2963f1051dc837a2364e4acf6eb7d80097c0f53cbdc3046ec8ec4b4e6e";
            };
          };
        in
        drv;

      yaml_elixir =
        let
          version = "2.12.2";
          drv = buildMix {
            inherit version;
            name = "yaml_elixir";
            appConfigPath = ./config;

            src = fetchHex {
              inherit version;
              pkg = "yaml_elixir";
              sha256 = "e7c1b10122f973e6558462d51c39026ba0e14afbc6745318e990ea82cfe9e159";
            };

            beamDeps = [
              yamerl
            ];
          };
        in
        drv;

    };
in
self

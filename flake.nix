{
  description = "Tablo";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";

    tql = {
      url = "github:Sobottasgithub/tql";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    ttp2 = {
      url = "github:Sobottasgithub/ttp2";
      inputs.nixpkgs.follows = "nixpkgs";

    };

    tud = {
      url = "github:Sobottasgithub/tud";
      inputs.nixpkgs.follows = "nixpkgs";

    };

    tablog = {
      url = "github:Sobottasgithub/tablog";
      inputs.nixpkgs.follows = "nixpkgs";

    };
  };

  outputs =
    {
      self,
      nixpkgs,
      tql,
      ttp2,
      tud,
      tablog,
    }:
    let
      system = "x86_64-linux";

      pkgs = import nixpkgs {
        inherit system;
      };

      version = "1.3";

      libtql = tql.packages.${system}.lib;
      libttp2 = ttp2.packages.${system}.lib;
      libtud = tud.packages.${system}.lib;
      libtablog = tablog.packages.${system}.lib;

      packages = with pkgs; [
        cmake
        gcc
        gnumake
        libtql
        libttp2
        libtablog
        arrow-cpp
      ];
    in
    {
      packages.${system} =
        let
          mkTabloPackage =
            {
              pname,
              buildTarget ? pname,

              enableLibtabcrypt ? false,

              enableNode ? false,
              enableClient ? false,
              enableMaster ? false,
              enableTests ? false,

              extraInputs ? [ ],
            }:
            pkgs.stdenv.mkDerivation {
              inherit pname version;

              src = ./.;

              meta = {
                description = "${pname} package";
                mainProgram = pname;
              };

              buildInputs = packages ++ extraInputs;

              configurePhase = ''
                cmake -B build -S $src \
                  -DCMAKE_BUILD_TYPE=Release \
                  -DDEF_LIBTABCRYPT=${if enableLibtabcrypt then "ON" else "OFF"} \
                  -DDEF_NODE=${if enableNode then "ON" else "OFF"} \
                  -DDEF_CLIENT=${if enableClient then "ON" else "OFF"} \
                  -DDEF_MASTER=${if enableMaster then "ON" else "OFF"} \
                  -DDEF_TESTS=${if enableTests then "ON" else "OFF"}
              '';

              buildPhase = ''
                cmake --build build \
                  --target ${buildTarget} \
                  -j$NIX_BUILD_CORES
              '';

              doCheck = enableTests;

              checkPhase = ''
                ctest --test-dir build --output-on-failure
              '';

              installPhase = ''
                cmake --install build --prefix=$out
                cp LICENSE $out/
              '';
            };

          libtabcrypt = mkTabloPackage {
            pname = "libtabcrypt";
            buildTarget = "tabcrypt";

            enableLibtabcrypt = true;
          };

          tablo-node = mkTabloPackage {
            pname = "tablo-node";

            enableNode = true;

            extraInputs = [
              libtablog
              libtabcrypt
              libtud
            ];
          };

          tablo-client = mkTabloPackage {
            pname = "tablo-client";

            enableClient = true;

            extraInputs = [
              libtablog
              libtabcrypt
            ];
          };

          tablo-master = mkTabloPackage {
            pname = "tablo-master";

            enableMaster = true;

            extraInputs = [
              libtablog
              libtabcrypt
              libtud
            ];
          };

          tablo-full = mkTabloPackage {
            pname = "tablo-full";
            buildTarget = "all";

            enableLibtabcrypt = true;

            enableNode = true;
            enableClient = true;
            enableMaster = true;

            extraInputs = [
              libtablog
              libtabcrypt
              libtud
            ];
          };

          tablo-tests = mkTabloPackage {
            pname = "tablo-tests";

            enableLibtabcrypt = true;
            enableTests = true;
          };

          tablo-test-runner-ux = pkgs.runCommand "tablo-test-runner-ux" {
            nativeBuildInputs = [ tablo-tests ];
          } ''
            set -o pipefail
            mkdir -p $out

            tablo-tests --list | tee $out/available-tests.txt
            grep -q "csv manager executes TQL" $out/available-tests.txt
            grep -q "worker executes a TQL request" $out/available-tests.txt

            tablo-tests "csv manager" | tee $out/filtered-run.txt
            grep -q "tests passed" $out/filtered-run.txt
          '';

          # CI builds the application only after the test derivation and its
          # installed runner interface have both completed successfully.
          tablo-full-after-tests = tablo-full.overrideAttrs (previous: {
            nativeBuildInputs = (previous.nativeBuildInputs or [ ]) ++ [ tablo-test-runner-ux ];
          });

          tablo-ci = pkgs.linkFarm "tablo-ci-${version}" [
            {
              name = "build";
              path = tablo-full-after-tests;
            }
            {
              name = "tests";
              path = tablo-tests;
            }
            {
              name = "test-runner-ux";
              path = tablo-test-runner-ux;
            }
          ];

          tablo = pkgs.symlinkJoin {
            name = "tablo-${version}";

            paths = [
              libtabcrypt
              tablo-node
              tablo-client
              tablo-master
            ];
          };

          mkTabloDocker =
            package: binary:
            pkgs.dockerTools.buildImage {
              name = binary;
              tag = version;

              config = {
                Cmd = [ "${package}/bin/${binary}" ];
              };
            };
        in
        {
          inherit
            tablo
            tablo-node
            tablo-client
            tablo-master
            tablo-full
            tablo-tests
            tablo-test-runner-ux
            tablo-full-after-tests
            tablo-ci
            libtabcrypt
            libtablog
            libttp2
            libtql
            libtud
            ;

          tests = tablo-tests;
          ci = tablo-ci;

          default = tablo;

          tablo-node-docker = mkTabloDocker tablo-node "tablo-node";

          tablo-master-docker = mkTabloDocker tablo-master "tablo-master";

          tablo-client-docker = mkTabloDocker tablo-client "tablo-client";
        };

      checks.${system} = {
        tests = self.packages.${system}.tablo-tests;
        build = self.packages.${system}.tablo-full-after-tests;
        test-runner-ux = self.packages.${system}.tablo-test-runner-ux;
      };

      devShells.${system}.default =
        let
          devPackages = packages ++ [
            pkgs.bridge-utils
            pkgs.clang-tools
            libtud
            libttp2
            libtql
            libtablog
          ];
        in
        pkgs.mkShell {
          packages = devPackages;

          inputsFrom = [
            self.packages.${system}.default
          ];

          shellHook = ''
            git status
            cmake -S . -B build -DCMAKE_EXPORT_COMPILE_COMMANDS=ON
          '';
        };
    };
}

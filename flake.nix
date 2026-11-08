{
  description = "Tablo";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";
  };

  outputs =
    { self, nixpkgs }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs { inherit system; };

      version = "1.1";

      packages = with pkgs; [
        cmake
        gcc
        gnumake
      ];
    in
    {

      packages.${system} =
        let
          tablo-full = pkgs.stdenv.mkDerivation {
            pname = "tablo-full";
            inherit version;
            src = ./.;

            meta = {
              description = "Full tablo package";
              mainProgram = "tablo-node";
            };

            buildInputs = packages;

            configurePhase = ''
              cmake -B build -S $src -DCMAKE_BUILD_TYPE=Release
            '';

            buildPhase = ''
              cmake --build build
            '';

            installPhase = ''
              cmake --install build --prefix=$out
              cp LICENSE $out/
            '';
          };

          mkTabloDocker =
            name: extraConfig:
            pkgs.dockerTools.buildImage {
              inherit name;
              tag = version;
              config = {
                Cmd = [ "${tablo-full}/bin/${name}" ];
              }
              // extraConfig;
            };
        in
        {
          inherit tablo-full;
          default = tablo-full;

          # Name the NixOS module and the overlay expect.
          tablo = tablo-full;

          tablo-node-docker = mkTabloDocker "tablo-node" { };
          tablo-master-docker = mkTabloDocker "tablo-master" { };

          # used for client containers not deployed via swarm
          tablo-client-docker = mkTabloDocker "tablo-client" { };
        };

      # NixOS deployment surface -------------------------------------------------

      overlays.default = _final: _prev: {
        # TODO: tablo-full is x86_64-linux only right now; key this off
        # final.stdenv.hostPlatform.system once it builds for more systems.
        tablo = self.packages.${system}.tablo-full;
      };

      nixosModules = {
        # Options and systemd units only — bring your own
        # `services.tablo.package`.
        tablo = import ./nix/modules;

        # Makes `pkgs.tablo` resolve to this flake's build.
        overlay = {
          nixpkgs.overlays = [ self.overlays.default ];
        };

        default = {
          imports = [
            self.nixosModules.tablo
            self.nixosModules.overlay
          ];
        };
      };

      # Helpers for describing a whole cluster at once; see nix/lib/cluster.nix.
      lib = import ./nix/lib/cluster.nix {
        inherit nixpkgs;
        lib = nixpkgs.lib;
        tabloModule = self.nixosModules.default;
      };

      checks.${system} = {
        cluster = import ./nix/tests/cluster.nix {
          # The overlay has to come in through `pkgs` rather than through
          # `nixosModules.default`: runNixOSTest pins each node's `nixpkgs.pkgs`
          # read-only, so a node may not set `nixpkgs.overlays` itself.
          pkgs = import nixpkgs {
            inherit system;
            overlays = [ self.overlays.default ];
          };
          tabloModule = self.nixosModules.tablo;
        };
      };

      devShells.${system}.default = pkgs.mkShell {
        inherit packages;

        inputsFrom = [ self.packages.${system}.default ];

        shellHook = ''
          git status
        '';
      };

    };
}

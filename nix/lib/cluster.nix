# Helpers for describing a whole Tablo cluster in one place.
#
# `mkCluster` turns a compact topology description into the per-host
# `nixosConfigurations` that deploy tools (nixos-rebuild --target-host,
# deploy-rs, colmena, ...) expect, so roles are assigned in one place rather
# than copied into every host's configuration.
#
# It does not wire the master to the nodes: the master dials a hardcoded
# address (see ../modules/master.nix), so the topology cannot be expressed in
# configuration yet. Host-specific bits (hardware, bootloader, networking)
# come from your own modules via `sharedModules` / per-host `modules`.
{
  lib,
  nixpkgs,
  tabloModule,
}:
{
  /*
    mkCluster :: AttrSet -> AttrSet of nixosSystem

    Example:

      mkCluster {
        master = { hostName = "tablo-master"; };
        nodes = [
          { hostName = "tablo-node-1"; }
          { hostName = "tablo-node-2"; }
        ];
        sharedModules = [ ./hosts/common.nix ];
      }
  */
  mkCluster =
    {
      system ? "x86_64-linux",
      master,
      nodes ? [ ],
      sharedModules ? [ ],
    }:
    let
      mkHost =
        host: roleConfig:
        nixpkgs.lib.nixosSystem {
          inherit system;
          modules = [
            tabloModule
            roleConfig
            { networking.hostName = host.hostName; }
          ]
          ++ sharedModules
          ++ (host.modules or [ ]);
        };

      masterHost = lib.nameValuePair master.hostName (
        mkHost master {
          services.tablo.master.enable = true;
        }
      );

      nodeHosts = map (
        n:
        lib.nameValuePair n.hostName (
          mkHost n {
            services.tablo.node = {
              enable = true;
              # Opens the node port to anything that can route to the host. To
              # restrict it to the master, set this to false and add a rule
              # scoped to the master's source address — on the nftables backend
              # (`networking.nftables.enable = true`), since
              # `networking.firewall.extraInputRules` is silently ignored under
              # the default iptables backend.
              openFirewall = true;
            };
          }
        )
      ) nodes;
    in
    lib.listToAttrs ([ masterHost ] ++ nodeHosts);
}

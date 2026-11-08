# NixOS deployment

Rough structure for deploying Tablo to a cluster of NixOS hosts. This replaces
the Docker Swarm path (`*.compose.yml`) for environments that are managed with
NixOS itself; the compose files stay for container deployments.

The option tree is deliberately small. Tablo's binaries parse neither argv nor
the environment, so the modules only expose what systemd itself can honour —
which role runs on a host, as whom, and whether the firewall opens. Everything
that would describe a *cluster* (endpoints, node lists, shared secret) is left
out until the binaries can read it; see [Known gaps](#known-gaps).

## Layout

| Path                  | Purpose                                                                 |
| --------------------- | ----------------------------------------------------------------------- |
| `modules/default.nix` | Aggregate module — imports the three below                              |
| `modules/common.nix`  | `services.tablo.{package,user,group}` plus the shared systemd hardening  |
| `modules/node.nix`    | `services.tablo.node.{enable,openFirewall}` — the `tablo-node` unit      |
| `modules/master.nix`  | `services.tablo.master.enable` — the `tablo-master` unit                 |
| `lib/cluster.nix`     | `mkCluster`: one topology description → per-host `nixosConfigurations`   |
| `tests/cluster.nix`   | NixOS VM test — 1 master + 2 nodes                                      |

## Flake outputs

```
nixosModules.default     # module + overlay, so pkgs.tablo just works
nixosModules.tablo       # module only; set services.tablo.package yourself
nixosModules.overlay     # only nixpkgs.overlays = [ overlays.default ]
overlays.default         # adds pkgs.tablo
lib.mkCluster            # cluster helper
checks.<system>.cluster  # the VM test
```

## Single host

```nix
{
  imports = [ tablo.nixosModules.default ];

  services.tablo.node = {
    enable = true;
    openFirewall = true;
  };
}
```

`services.tablo.node.port` is read-only at 8080 — refer to it in your own
firewall rules rather than repeating the literal.

## Whole cluster

```nix
# flake.nix of your deployment repo
nixosConfigurations = tablo.lib.mkCluster {
  master = { hostName = "tablo-master"; };
  nodes = [
    { hostName = "tablo-node-1"; }
    { hostName = "tablo-node-2"; }
  ];
  sharedModules = [ ./hosts/common.nix ];
};
```

Deploy with `nixos-rebuild switch --flake .#tablo-node-1 --target-host ...`,
or hand the same `nixosConfigurations` to deploy-rs / colmena.

## Known gaps

The modules can place and start the right binary on the right host. They
cannot yet form a working cluster, because the binaries take no configuration:

- `tablo-node` hardcodes `0.0.0.0:8080` (`TabloNode/src/utils/socket.cpp`).
- `tablo-master` dials one hardcoded node, `172.21.0.2:8080`
  (`TabloMaster/src/utils/socket.cpp`), and accepts no client connections of
  its own. For the master to find a node today, that node has to be reachable
  at exactly that address.
- `libtabcrypt` exists but nothing on the wire calls it, so master <-> node
  traffic is plaintext and unauthenticated.

Once the binaries parse argv or the environment, these are the options to add
back, per role:

| Option                           | Needs                                               |
| -------------------------------- | --------------------------------------------------- |
| `node.listenAddress` / `port`    | `tablo-node` reading a bind endpoint                |
| `node.workers`                   | a configurable thread-pool size                     |
| `master.nodes`                   | `tablo-master` reading a node list                  |
| `master.listenAddress` / `port`  | `tablo-master` serving `tablo-client`               |
| `cluster.secretFile`             | the handshake using the `libtabcrypt` shared secret |
| `cluster.name`                   | a cluster identifier on the wire                    |

`cluster.secretFile` should arrive as a systemd credential
(`LoadCredential=`), not an environment variable, so the secret never reaches
the Nix store or the process environment.

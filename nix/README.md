# NixOS deployment

Rough structure for deploying Tablo to a cluster of NixOS hosts. This replaces
the Docker Swarm path (`*.compose.yml`) for environments that are managed with
NixOS itself; the compose files stay for container deployments.

The option tree is deliberately small. Tablo's binaries parse neither argv nor
the environment, so the modules only expose what systemd and polkit can
honour — which role runs on a host, as whom, whether the firewall opens, and
who may manage the units. Everything that would describe a *cluster*
(endpoints, node lists, shared secret) is left out until the binaries can read
it; see [Known gaps](#known-gaps).

## Layout

| Path                       | Purpose                                                                |
| -------------------------- | ---------------------------------------------------------------------- |
| `modules/default.nix`      | Aggregate module — imports the four below                              |
| `modules/common.nix`       | `services.tablo.{package,user,group}` plus the shared systemd hardening |
| `modules/node.nix`         | `services.tablo.node.{enable,openFirewall}` — the `tablo-node` unit     |
| `modules/master.nix`       | `services.tablo.master.enable` — the `tablo-master` unit                |
| `modules/local-access.nix` | `services.tablo.localAccess.{enable,group}` — local operator group      |
| `lib/cluster.nix`          | `mkCluster`: one topology description → per-host `nixosConfigurations`  |
| `tests/cluster.nix`        | NixOS VM test — 1 master + 2 nodes + the local-access group             |

## Flake outputs

```
nixosModules.default     # module + overlay, so pkgs.tablo just works
nixosModules.tablo       # module only; set services.tablo.package yourself
nixosModules.overlay     # only nixpkgs.overlays = [ overlays.default ]
overlays.default         # adds pkgs.tablo
lib.mkCluster            # cluster helper
checks.<system>.cluster  # the VM test
```

`nixosModules.default` cannot be used inside `runNixOSTest` nodes: the test
driver pins each node's `nixpkgs.pkgs` read-only, so a node may not set
`nixpkgs.overlays`. Pass `nixosModules.tablo` and bring the overlay in through
the `pkgs` you call the tester from — see `checks` in `flake.nix`.

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

## Letting operators manage Tablo without root

```nix
{
  services.tablo.localAccess.enable = true;          # creates `tablo-users`
  users.users.alice.extraGroups = [ "tablo-users" ];
}
```

Members may then `systemctl start|stop|restart|try-restart|reload-or-restart`
the Tablo units that run on that host, without authenticating. The grant is
scoped to those unit names; it is not a grant over systemd in general, and it
deliberately excludes `enable`/`disable`, since on NixOS that is decided
declaratively.

The group is kept separate from `services.tablo.group` (the service account's
own group) so membership never implies the service's privileges. Treat
membership as a trusted role: restarting the node interrupts whatever it is
running.

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

## Local access: what was possible, and what was chosen

Tablo exposes no local interface — no control socket, no CLI that talks to a
running service, no state on disk — so the options for a local group are
limited. Everything considered:

| Mechanism                                                                                  | Verdict                                                                                                                                                                                                                                      |
| ------------------------------------------------------------------------------------------ | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **polkit**: group may start/stop/restart the Tablo units                                   | **Implemented.** Needs no code changes and is not bypassable; the VM test proves a member can restart `tablo-node` while a non-member cannot.                                                                                                 |
| **AF_UNIX control socket** owned by the group (`SocketGroup=`, `SocketMode=0660`)           | **The real answer, needs code.** Tablo is AF_INET only. This is how nixpkgs does it for lxd, kubo, weblate, and it would make the group an *interaction* boundary rather than only a management one.                                          |
| **Gating execution** of the binaries (group-owned wrapper, mode `0750`)                     | **Rejected — not a boundary.** Store paths are world-executable (`r-xr-xr-x`), so any local user can run `/nix/store/…/bin/tablo-node` directly, wrapper or not.                                                                              |
| **Group-readable state dir** (tmpfiles `a+` ACL)                                            | **No value today.** Nothing writes state; `/var/lib/tablo` exists only to give the hardened units one writable path.                                                                                                                          |
| **Journal access** for members                                                              | **Possible, but unscoped.** `journalctl -u tablo-node` needs `systemd-journal` or `adm`, which grants *all* system logs. A scoped variant is `LogNamespace=tablo` plus an ACL on `/var/log/journal/%m.tablo`, at the cost of `journalctl -u` no longer finding the units. Not enabled — add the group yourself if the trade-off suits you. |
| **Restricting local connections** to the node port (iptables `--gid-owner` / nft `meta skgid`) | **Possible but hollow.** The node listens on `0.0.0.0`, so remote hosts are unaffected, and owner matching is backend-specific. Only worth it alongside `openFirewall = false` and a loopback-only deployment.                               |

## Known gaps

The modules can place and start the right binary on the right host, and let
operators manage it. They cannot yet form a working cluster, because the
binaries take no configuration:

- `tablo-node` hardcodes `0.0.0.0:8080` (`TabloNode/src/utils/socket.cpp`).
- `tablo-master` dials one hardcoded node, `172.21.0.2:8080`
  (`TabloMaster/src/utils/socket.cpp`), and accepts no client connections of
  its own. For the master to find a node today, that node has to be reachable
  at exactly that address.
- With no node at that address, `tablo-master` prints `TIMEOUT` and **exits 0**
  within a second of starting. Because the exit is clean,
  `Restart=on-failure` does not retry and the unit simply goes inactive. The
  VM test asserts this current behaviour rather than pretending the master
  stays up.
- `libtabcrypt` exists but nothing on the wire calls it, so master <-> node
  traffic is plaintext and unauthenticated.

Once the binaries parse argv or the environment, these are the options to add
back, per role:

| Option                          | Needs                                               |
| ------------------------------- | --------------------------------------------------- |
| `node.listenAddress` / `port`   | `tablo-node` reading a bind endpoint                |
| `node.workers`                  | a configurable thread-pool size                     |
| `master.nodes`                  | `tablo-master` reading a node list                  |
| `master.listenAddress` / `port` | `tablo-master` serving `tablo-client`               |
| `cluster.secretFile`            | the handshake using the `libtabcrypt` shared secret |
| `cluster.name`                  | a cluster identifier on the wire                    |

`cluster.secretFile` should arrive as a systemd credential
(`LoadCredential=`), not an environment variable, so the secret never reaches
the Nix store or the process environment.

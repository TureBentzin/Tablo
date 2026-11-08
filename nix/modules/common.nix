# Shared Tablo options: package and service account.
#
# Role-specific options live in ./node.nix and ./master.nix.
#
# Deliberately minimal: Tablo's binaries parse neither argv nor the
# environment, so this module only exposes knobs that systemd itself honours.
# Cluster identity, endpoints and the libtabcrypt secret are absent on purpose
# — see nix/README.md for the list of options that can be added once the
# binaries read configuration.
{
  lib,
  config,
  pkgs,
  ...
}:
let
  cfg = config.services.tablo;

  anyRoleEnabled = cfg.node.enable || cfg.master.enable;
in
{
  options.services.tablo = {
    package = lib.mkPackageOption pkgs "tablo" { };

    user = lib.mkOption {
      type = lib.types.str;
      default = "tablo";
      description = "User the Tablo services run as. Created when left at the default.";
    };

    group = lib.mkOption {
      type = lib.types.str;
      default = "tablo";
      description = "Group the Tablo services run as. Created when left at the default.";
    };

    # Internals shared between the role modules; not part of the public API.
    internal.serviceDefaults = lib.mkOption {
      type = lib.types.attrs;
      internal = true;
      visible = false;
      description = "Common systemd `serviceConfig` for every Tablo unit.";
    };
  };

  config = lib.mkIf anyRoleEnabled {
    services.tablo.internal.serviceDefaults = {
      User = cfg.user;
      Group = cfg.group;

      # Nothing writes state yet; this gives the units one writable path for
      # when they do, since ProtectSystem=strict seals off everything else.
      StateDirectory = "tablo";
      WorkingDirectory = "/var/lib/tablo";

      Restart = "on-failure";
      RestartSec = "5s";

      # Hardening. Tablo only needs an AF_INET socket and its state dir.
      AmbientCapabilities = [ ];
      CapabilityBoundingSet = [ ];
      LockPersonality = true;
      MemoryDenyWriteExecute = true;
      NoNewPrivileges = true;
      PrivateDevices = true;
      PrivateTmp = true;
      ProtectClock = true;
      ProtectControlGroups = true;
      ProtectHome = true;
      ProtectHostname = true;
      ProtectKernelLogs = true;
      ProtectKernelModules = true;
      ProtectKernelTunables = true;
      ProtectProc = "invisible";
      ProtectSystem = "strict";
      RestrictAddressFamilies = [
        "AF_INET"
        "AF_INET6"
        "AF_UNIX"
      ];
      RestrictNamespaces = true;
      RestrictRealtime = true;
      RestrictSUIDSGID = true;
      SystemCallArchitectures = "native";
      SystemCallFilter = [
        "@system-service"
        "~@privileged"
        "~@resources"
      ];
      UMask = "0077";
    };

    users.users = lib.mkIf (cfg.user == "tablo") {
      tablo = {
        isSystemUser = true;
        group = cfg.group;
        home = "/var/lib/tablo";
        description = "Tablo service account";
      };
    };

    users.groups = lib.mkIf (cfg.group == "tablo") {
      tablo = { };
    };

    # `tablo-client` is a CLI, so make it available to operators on any host
    # that participates in the cluster.
    environment.systemPackages = [ cfg.package ];
  };
}

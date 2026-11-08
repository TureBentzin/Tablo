# Tablo master: dispatches work to the nodes and serves `tablo-client`.
#
# `enable` is the only option. `tablo-master` dials a single hardcoded node at
# 172.21.0.2:8080 (`TabloMaster/src/utils/socket.cpp`), accepts no client
# connections of its own, and parses neither argv nor the environment — so
# there is nothing here to configure, not even a port to open. One of the
# cluster's nodes has to be reachable at that address for the master to find
# it.
{
  lib,
  config,
  ...
}:
let
  cfg = config.services.tablo;
in
{
  options.services.tablo.master.enable = lib.mkEnableOption "the Tablo master";

  config = lib.mkIf cfg.master.enable {
    systemd.services.tablo-master = {
      description = "Tablo master";
      documentation = [ "https://github.com/Sobottasgithub/Tablo" ];

      wantedBy = [ "multi-user.target" ];
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];

      serviceConfig = cfg.internal.serviceDefaults // {
        ExecStart = lib.getExe' cfg.package "tablo-master";
      };
    };
  };
}

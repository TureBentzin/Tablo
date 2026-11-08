# Tablo worker node: accepts task connections and runs them on a thread pool.
{
  lib,
  config,
  ...
}:
let
  cfg = config.services.tablo;
  ncfg = cfg.node;
in
{
  options.services.tablo.node = {
    enable = lib.mkEnableOption "the Tablo worker node";

    port = lib.mkOption {
      type = lib.types.port;
      default = 8080;
      readOnly = true;
      description = ''
        Port `tablo-node` listens on. Read-only: the binary hardcodes
        0.0.0.0:8080 (`TabloNode/src/utils/socket.cpp`) and parses neither
        argv nor the environment. Exposed so firewall rules elsewhere in your
        configuration can refer to it instead of repeating the literal.
      '';
    };

    openFirewall = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Open {option}`services.tablo.node.port` in the host firewall. This
        opens it to everything that can route to this host; prefer leaving it
        off and adding a rule scoped to the master's source address.
      '';
    };
  };

  config = lib.mkIf ncfg.enable {
    systemd.services.tablo-node = {
      description = "Tablo worker node";
      documentation = [ "https://github.com/Sobottasgithub/Tablo" ];

      wantedBy = [ "multi-user.target" ];
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];

      serviceConfig = cfg.internal.serviceDefaults // {
        ExecStart = lib.getExe' cfg.package "tablo-node";
      };
    };

    networking.firewall.allowedTCPPorts = lib.mkIf ncfg.openFirewall [ ncfg.port ];
  };
}

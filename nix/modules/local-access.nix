# A group whose members can work with the Tablo services on the host they are
# logged into, without becoming root.
#
# What this can grant today is narrow, because Tablo exposes no local interface
# at all: no control socket, no CLI that talks to a running service, no state
# on disk. The one real local interaction is managing the units, so that is
# what the group gets, via polkit.
#
# See nix/README.md for the alternatives that were considered and why they are
# not here — in particular that gating *execution* of the binaries is not a
# boundary at all (their store paths are world-executable), and that the
# forward-looking answer is an AF_UNIX control socket owned by this group.
{
  lib,
  config,
  ...
}:
let
  cfg = config.services.tablo;
  acfg = cfg.localAccess;

  # Only the units that actually exist on this host.
  units =
    lib.optional cfg.node.enable "tablo-node.service"
    ++ lib.optional cfg.master.enable "tablo-master.service";

  # Deliberately excludes `enable`/`disable` (manage-unit-files): on NixOS
  # which units are enabled is decided declaratively, not at runtime.
  verbs = [
    "start"
    "stop"
    "restart"
    "try-restart"
    "reload-or-restart"
  ];

  toJsArray = xs: "[" + lib.concatMapStringsSep ", " (x: ''"${x}"'') xs + "]";
in
{
  options.services.tablo.localAccess = {
    enable = lib.mkEnableOption ''
      a group whose members may start, stop and restart the Tablo units on
      this host without authenticating. Members gain control over the local
      Tablo services, so treat membership as a trusted role
    '';

    group = lib.mkOption {
      type = lib.types.str;
      default = "tablo-users";
      description = ''
        Group granted local control over the Tablo units. Created when left at
        the default; add users with
        {option}`users.users.<name>.extraGroups`.

        Kept separate from {option}`services.tablo.group` (the service
        account's own group) so that membership never implies the service's
        own privileges.
      '';
    };
  };

  config = lib.mkIf acfg.enable (
    lib.mkMerge [
      {
        users.groups = lib.mkIf (acfg.group == "tablo-users") {
          tablo-users = { };
        };

        warnings =
          lib.optional (units == [ ]) ''
            services.tablo.localAccess is enabled but no Tablo role runs on
            this host, so the group has nothing to manage. Enable
            services.tablo.node or services.tablo.master.
          ''
          ++ lib.optional (acfg.group != "tablo-users" && !(config.users.groups ? ${acfg.group})) ''
            services.tablo.localAccess.group is set to "${acfg.group}", which
            this configuration does not define. Create it with
            `users.groups."${acfg.group}" = { };` or the polkit rule will
            never match.
          '';
      }

      (lib.mkIf (units != [ ]) {
        security.polkit.enable = true;

        # Tighten with `subject.local && subject.active` if membership should
        # only count at a physical seat rather than over SSH.
        security.polkit.extraConfig = ''
          // nixos/tablo: let ${acfg.group} manage the local Tablo units.
          // Enabled via services.tablo.localAccess.enable.
          polkit.addRule(function(action, subject) {
            if (action.id != "org.freedesktop.systemd1.manage-units") {
              return;
            }
            if (!subject.isInGroup("${acfg.group}")) {
              return;
            }
            var units = ${toJsArray units};
            var verbs = ${toJsArray verbs};
            if (units.indexOf(action.lookup("unit")) >= 0 &&
                verbs.indexOf(action.lookup("verb")) >= 0) {
              return polkit.Result.YES;
            }
          });
        '';
      })
    ]
  );
}

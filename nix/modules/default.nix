# Aggregate NixOS module for Tablo.
#
# Importing this gives you the `services.tablo.*` option tree and the systemd
# units for every role. It deliberately does *not* touch `nixpkgs.overlays`:
# either import `tablo.nixosModules.overlay` as well (the `default` module does
# that for you) or set `services.tablo.package` by hand.
{
  imports = [
    ./common.nix
    ./node.nix
    ./master.nix
  ];
}

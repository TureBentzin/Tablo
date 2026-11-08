# NixOS VM test: one master, two nodes, all on one virtual network.
#
# Rough skeleton. It currently proves the module produces units that start,
# that a node's port is reachable from the master, and that the localAccess
# group really can manage the units without root. The end-to-end assertion
# (submit a task through `tablo-client`, observe a result) is marked TODO
# because the wire protocol is not finished.
#
# Run with: nix build .#checks.x86_64-linux.cluster -L
{ pkgs, tabloModule }:
pkgs.testers.runNixOSTest {
  name = "tablo-cluster";

  nodes =
    let
      common = {
        imports = [ tabloModule ];
      };
    in
    {
      master = {
        imports = [ common ];
        services.tablo.master.enable = true;
      };

      node1 = {
        imports = [ common ];

        services.tablo = {
          node = {
            enable = true;
            openFirewall = true;
          };
          localAccess.enable = true;
        };

        users.users.operator = {
          isNormalUser = true;
          extraGroups = [ "tablo-users" ];
        };

        users.users.outsider.isNormalUser = true;
      };

      node2 = {
        imports = [ common ];
        services.tablo.node = {
          enable = true;
          openFirewall = true;
        };
      };
    };

  testScript = ''
    start_all()

    with subtest("nodes come up and listen"):
        for node in (node1, node2):
            node.wait_for_unit("tablo-node.service")
            node.wait_for_open_port(8080)

    with subtest("master unit runs, and today exits immediately"):
        # tablo-master dials its hardcoded 172.21.0.2, gets POLLHUP, prints
        # "TIMEOUT" and exits 0 — so the unit goes inactive right after start
        # and Restart=on-failure never fires. Turn this into a plain
        # wait_for_unit once the master can be pointed at a real node.
        master.wait_until_succeeds(
            "journalctl -u tablo-master.service | grep -q TIMEOUT"
        )
        state = master.succeed(
            "systemctl show -p ActiveState --value tablo-master.service"
        ).strip()
        assert state == "inactive", f"expected the master to have exited, got {state}"

    with subtest("master can reach every node"):
        for host in ("node1", "node2"):
            master.succeed(f"timeout 5 bash -c '</dev/tcp/{host}/8080'")

    with subtest("tablo-users may manage the node unit, others may not"):
        node1.succeed("su -l operator -c 'systemctl restart tablo-node.service'")
        node1.wait_for_unit("tablo-node.service")
        node1.fail("su -l outsider -c 'systemctl restart tablo-node.service'")
        # The grant is scoped to Tablo's own units.
        node1.fail("su -l operator -c 'systemctl restart systemd-journald.service'")

    # TODO: submit a task via tablo-client and assert on the result once the
    # master <-> node protocol is implemented. Until the master stops dialling
    # its hardcoded 172.21.0.2, it cannot talk to either node above.
  '';
}

# NixOS VM test: one master, two nodes, all on one virtual network.
#
# Rough skeleton. It currently proves the module produces units that start and
# that a node's port is reachable from the master. The end-to-end assertion
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
        services.tablo.node = {
          enable = true;
          openFirewall = true;
        };
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

    with subtest("master comes up"):
        master.wait_for_unit("tablo-master.service")

    with subtest("master can reach every node"):
        for host in ("node1", "node2"):
            master.succeed(f"timeout 5 bash -c '</dev/tcp/{host}/8080'")

    # TODO: submit a task via tablo-client and assert on the result once the
    # master <-> node protocol is implemented. Until the master stops dialling
    # its hardcoded 172.21.0.2, it cannot talk to either node above.
  '';
}

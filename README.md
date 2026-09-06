# Tablo

## Test with Nix

Run the complete deterministic test suite during a Nix build:

```sh
nix build -L .#tests
```

Run the tests, verify the test-runner UX, and build every Tablo component with
one command:

```sh
nix build -L .#ci
```

The CI build is gated: the complete test suite and test-runner validation must
finish successfully before the full application build starts. `nix flake check
-L` uses the same checks and dependency ordering.

The test executable is also convenient for local iteration while retaining the
same pinned Nix dependencies:

```sh
nix run .#tests
nix run .#tests -- --list
nix run .#tests -- "csv manager"
```

The tests do not need network access and do not depend on host interfaces,
ports, timing services, or files outside the Nix build sandbox.

## Deploy with NIX

### 1 Allow following ports in your firewall

The following ports are used to establish the network tablo needs:

- **4000**
- **4001**
- **4003**
- **4004**

### 2 Deploy

```cmd
sudo nix-collect-garbage -d
nix build --log-format bar-with-logs
nix run .#tablo-master -- --interface INTERFACENAME
nix run .#tablo-node -- --interface INTERFACENAME
nix run .#tablo-client -- --master MASTERIPV4
```

## Deploy with DOCKER

### 1 Allow following ports in your firewall

The following ports are used to establish the network tablo needs:

- **4003**

### 2 Deploy

In docker swarm mode:

```cmd
./build-image-nix.sh
docker stack deploy --compose-file nix.compose.yml NAME --detach=false
tablo-client --master YOURMASTERIP
```

### Using the nix generated docker images

The flake in this repository allowes you to build minimal docker images that avoid as much bloat as possible.

To use this feature, you NEED to use nix. Download available at: https://nixos.org/

# Take a look at Tablos networking libs:
**Tablo Transfer Protocol:** [TTP2](https://github.com/Sobottasgithub/TTP2)

**Tablo UDP Discovery:** [TUD](https://github.com/Sobottasgithub/TUD)

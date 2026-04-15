# ufw-manager

<a target="_blank" href="https://hub.docker.com/r/mahelbir/ufw-manager"><img src="https://img.shields.io/docker/pulls/mahelbir/ufw-manager" /></a>
<a target="_blank" href="https://hub.docker.com/r/mahelbir/ufw-manager"><img src="https://img.shields.io/docker/v/mahelbir/ufw-manager?label=docker%20image%20ver." /></a>

A thin, ergonomic wrapper around the host's UFW firewall — interactive
wizards, a REPL, and sane defaults for servers that run Docker behind
[ufw-docker](https://github.com/chaifeng/ufw-docker). Ships as a 3-line
Dockerfile (no host agent, no bind-mounts, no ufw inside the container) or as
a standalone bash script you can drop on any Linux host.

## ⭐ Why

If you run `ufw` alongside Docker, you have probably hit the classic
port-leak pitfall: `ufw deny` doesn't block published container ports. Docker
inserts its own rules into the `DOCKER-USER` / `FORWARD` chains before ufw's
`INPUT` rules ever see the traffic, so the usual shorthand silently does
nothing for containers. The standard fix is `ufw-docker`, which relocates
rules to the `FORWARD` chain via `ufw route ...`.

`ufw-manager` makes that workflow painless:

- **Route mode is on by default** — every `allow` / `deny` / `delete` is sent
  as `ufw route ...`, so rules actually apply to published container ports.
- **Interactive wizards** for `allow`, `deny`, `delete` — port, IP, protocol
  prompts with a preview before execution.
- **Multi-rule numbered delete** that sorts descending, so reindexing
  doesn't shift later targets (a common footgun with `ufw delete N`).
- **REPL shell** so you stop retyping `docker compose run --rm ufw-manager …`
  for every command.
- **Zero host install (Docker mode)** — the image only carries `bash` +
  `nsenter` and runs ufw inside the host's namespaces. No ufw inside the
  container, no bind-mounts, no socket.
- **Runs standalone too** — drop the script on a Linux host and it
  auto-detects that it's already on the host and skips the namespace hop.

## 🔧 How to Install

### 🐳 Docker (Recommended)

Grab the compose file and start the container in the background:

```bash
curl -O https://raw.githubusercontent.com/mahelbir/ufw-manager/main/docker-compose.yaml
docker compose up -d
```

The compose file runs with `pid: host`, `network_mode: host`, and
`privileged: true`. These are required — the container enters PID 1's mount,
uts, ipc, net, and pid namespaces via `nsenter` so ufw runs on the host using
the host's own binary and `/etc/ufw` config. Nothing is bind-mounted;
iptables state lives entirely on the host.

### 💪🏻 Non-Docker (bash)

Clone the repo and drop the script into `/usr/local/bin`:

```bash
git clone https://github.com/mahelbir/ufw-manager.git
cd ufw-manager
sudo install -m 755 src/ufw-manager /usr/local/bin/ufw-manager
```

When run directly on the host, the script compares its own mount namespace
against PID 1's and, since they match, calls `ufw` directly — no `nsenter`,
no Docker required.

## ▶️ Usage

### 🐳 Docker

Open a REPL on the running container:

```bash
docker exec -it ufw-manager ufw shell
```

Or run one-shot commands:

```bash
docker exec -it ufw-manager ufw allow
docker exec -it ufw-manager ufw list
```

If you'd rather not keep a container running, use the disposable form:

```bash
docker compose run --rm ufw-manager shell
docker compose run --rm ufw-manager list
```

### 💪🏻 Non-Docker

```bash
sudo ufw-manager shell
sudo ufw-manager allow
sudo ufw-manager list
```

## 🚦 Route Mode

`ufw route ...` writes rules to the `FORWARD` chain, which is what Docker's
published-port traffic passes through. Plain `ufw ...` writes to `INPUT`,
which only covers traffic terminating on the host itself. On a server that
mostly manages forwarded container traffic, route mode is what you want
nearly all of the time — and it's the default here.

When route mode is **on**, every rule verb is transparently prefixed:

```
allow from 1.2.3.4 to any port 5432 proto tcp
  → ufw route allow from 1.2.3.4 to any port 5432 proto tcp
```

When route mode is **off**, the rule is sent to ufw unchanged, and you can
use native shorthand like `allow 22/tcp` to protect the host's own services.

**Toggle at runtime:**

```bash
ufw route-mode            # show current mode
ufw route-mode on         # force on
ufw route-mode off        # force off
ufw route-mode toggle     # flip
```

Inside the REPL, the prompt shows the active mode in brackets:

```
ufw[on]> allow from 1.2.3.4 to any port 5432 proto tcp
ufw[on]> route-mode off
route-mode: off
ufw[off]> allow 22/tcp
```

**Set the initial mode via `ROUTE_MODE` env var:**

```bash
# Docker (one-shot)
docker compose run --rm -e ROUTE_MODE=off ufw-manager allow 22/tcp

# Docker (exec into running container)
docker exec -it -e ROUTE_MODE=off ufw-manager ufw allow 22/tcp

# Standalone
sudo ROUTE_MODE=off ufw-manager allow 22/tcp
```

Or set it permanently in `docker-compose.yaml`:

```yaml
services:
  ufw-manager:
    image: mahelbir/ufw-manager
    environment:
      ROUTE_MODE: "on"   # or "off"
    # ...
```

Accepted values: `on` (default) or `off`.

## 📝 Commands

| Command                        | Description                                          |
|--------------------------------|------------------------------------------------------|
| `allow` / `deny`               | Interactive wizard (port → IP → protocol → preview)  |
| `allow <args>` / `deny <args>` | Pass args to ufw (route-prefixed when mode is on)    |
| `delete`                       | Interactive wizard, accepts multiple numbers at once |
| `delete <args>`                | Pass args to ufw                                     |
| `list`                         | Alias for `ufw status numbered`                      |
| `route-mode [on/off/toggle]`   | Show or change route mode                            |
| `shell`                        | Interactive REPL                                     |
| `help`                         | Built-in help                                        |

Any other command is forwarded to host ufw as-is — with the route prefix
applied to rule verbs when route mode is on.

## 🔄 How to Update

### 🐳 Docker

```bash
docker compose pull
docker compose up -d --force-recreate
```

### 💪🏻 Non-Docker

Pull the latest changes and reinstall:

```bash
cd ufw-manager
git pull
sudo install -m 755 src/ufw-manager /usr/local/bin/ufw-manager
```

## 🗣️ Discussion / Bug Report

- [GitHub Issues](https://github.com/mahelbir/ufw-manager/issues)

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
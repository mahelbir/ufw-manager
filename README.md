# ufw-manager

<a target="_blank" href="https://hub.docker.com/r/mahelbir/ufw-manager"><img src="https://img.shields.io/docker/pulls/mahelbir/ufw-manager" /></a>
<a target="_blank" href="https://hub.docker.com/r/mahelbir/ufw-manager"><img src="https://img.shields.io/docker/v/mahelbir/ufw-manager?label=docker%20image%20ver." /></a>

A thin, ergonomic wrapper around the host's UFW firewall — interactive
wizards, a REPL, template shortcuts, and sane defaults for
servers that run Docker behind
[ufw-docker](https://github.com/chaifeng/ufw-docker). Ships as a tiny Alpine
image (no host agent, no ufw inside the container) or as a standalone bash
script you can drop on any Linux host.

## ⭐ Why

`ufw deny` doesn't block published Docker container ports — Docker's rules
sit in `FORWARD` before ufw's `INPUT` ever sees the traffic. The fix is
`ufw route ...` (à la `ufw-docker`); `ufw-manager` makes it the default.

- **Route mode on by default** — rules go to `FORWARD`, so they actually
  apply to container ports.
- **Interactive wizards** with a preview before execution.
- **Safe multi-rule delete** — sorted descending so indexes don't shift.
- **REPL shell** — no more retyping `docker compose run --rm ufw-manager …`.
- **Zero host install** in Docker mode (runs ufw via `nsenter` in the host's
  namespaces) — or drop the script standalone on any Linux host.
- **[Template shortcuts](TEMPLATES.md)** — `.tpl` files turn `ufw pg`,
  `ufw ssh`, etc. into pre-filled wizards.

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

## 🧩 Templates

Templates turn repetitive rules into single-word commands. Drop a `.tpl`
file into the templates folder and `ufw <name>` opens the wizard with port
and protocol pre-filled — usually only the IP is left for you to type or
pass as an arg:

```bash
ufw pg                 # allow:5432:$1:tcp → prompts for IP
ufw pg 1.2.3.4         # same, IP from argv
```

Full file format, placeholder resolution order, and more examples in
**[TEMPLATES.md](TEMPLATES.md)**.

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

**Set the initial mode via `UFW_ROUTE_MODE` env var:**

```bash
# Docker (one-shot)
docker compose run --rm -e UFW_ROUTE_MODE=off ufw-manager allow 22/tcp

# Docker (exec into running container)
docker exec -it -e UFW_ROUTE_MODE=off ufw-manager ufw allow 22/tcp

# Standalone
sudo UFW_ROUTE_MODE=off ufw-manager allow 22/tcp
```

Or set it permanently in `docker-compose.yaml`:

```yaml
services:
  ufw-manager:
    image: mahelbir/ufw-manager
    environment:
      UFW_ROUTE_MODE: "on"   # or "off"
    # ...
```

Accepted values: `on` (default) or `off`.

## 📝 Commands

| Command                        | Description                                         |
|--------------------------------|-----------------------------------------------------|
| `allow` / `deny`               | Interactive wizard (port → IP → protocol → preview) |
| `allow [args]` / `deny [args]` | Pass args to ufw (route-prefixed when mode is on)   |
| `delete` / `del`               | Interactive wizard — numbers or `:port[/proto]`     |
| `delete [args]` / `del [args]` | Pass args to ufw                                    |
| `list` /  `ls`                 | Alias for `ufw status numbered`                     |
| `route-mode [on/off/toggle]`   | Show or change route mode                           |
| `shell`                        | Interactive REPL                                    |
| `<name> [args]`                | Run `<name>.tpl` — see [TEMPLATES.md](TEMPLATES.md) |
| `help`                         | Built-in help                                       |

Any other command is forwarded to host ufw as-is — with the route prefix
applied to rule verbs when route mode is on.

## 🔄 How to Update

### 🐳 Docker

It is recommended to check the latest [docker-compose.yaml](docker-compose.yaml) for any changes before updating.

```bash
docker compose pull
docker compose up -d --force-recreate
```

### 💪🏻 Non-Docker

Pull the latest changes and reinstall:

```bash
git pull
sudo install -m 755 src/ufw-manager /usr/local/bin/ufw-manager
```

## 🗣️ Discussion / Bug Report

- [GitHub Issues](https://github.com/mahelbir/ufw-manager/issues)

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
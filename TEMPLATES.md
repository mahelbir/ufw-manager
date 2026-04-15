# Templates

`ufw-manager` ships a small template engine so you can turn `ufw postgresql`, `ufw http`, `ufw ssh` etc. into one-liners that open the rule wizard with everything except
your IP pre-filled. Templates are plain text files with a `.tpl` extension,
discovered at runtime — no rebuild needed to add new ones.

## File format

One rule line, plus optional placeholder fallbacks and `#` comments:

```
action:port:ip:proto
$N=<shell command>
# free-form comment
```

- **`action`** — one of `allow`, `deny`, `reject`, `limit`.
- **`port`** — a single port (`5432`) or a range (`5000:5010`).
- **`ip`** — a CIDR (`10.0.0.0/24`), a single address, or `any`.
- **`proto`** — `tcp`, `udp`, or `both` (expands into two rules).
- **Any field** may be written as `$1`, `$2`, … to defer it to a placeholder.
- **`$N=<shell>`** lines give that placeholder a fallback value; the command
  runs through `bash -c` and its stdout (trimmed) becomes the value.

Only the first rule line in a file is used. Blank lines and `# comments` are
ignored.

## Placeholder resolution order

When a field is `$N`, `ufw-manager` resolves it in this order and stops at the
first non-empty result:

1. **Positional arg** — `ufw pg 1.2.3.4` → `$1 = 1.2.3.4`.
2. **`$N=` shell output** — if the template has `$1=curl -s ifconfig.me`, run
   that command and use its output.
3. **Interactive prompt** — fall through to the wizard, which asks for the
   field the normal way.

Either way the wizard still prints a preview of the resulting `ufw` command
and waits for confirmation before touching the firewall.

## Usage

```bash
ufw pg                 # prompts for IP
ufw pg 1.2.3.4         # fills IP from argv
ufw mysql 10.0.0.0/24  # CIDR works
ufw ssh 1.2.3.4    # ssh template → allow:22:$1:tcp
```

Any unknown subcommand is tried as a template first; if no matching `.tpl`
exists, the argument is passed through to host `ufw` unchanged.

## Built-in templates

The repo ships these under `src/templates/default/`:

| Command             | Rule                 |
|---------------------|----------------------|
| `ufw postgresql/pg` | `allow:5432:$1:tcp`  |
| `ufw mysql`         | `allow:3306:$1:tcp`  |
| `ufw redis`         | `allow:6379:$1:tcp`  |
| `ufw mongo`         | `allow:27017:$1:tcp` |
| `ufw ssh`           | `allow:22:$1:tcp`    |
| `ufw http`          | `allow:80:$1:tcp`    |
| `ufw https`         | `allow:443:$1:tcp`   |

## Directory layout

```
$UFW_TEMPLATES_DIR/
├── default/   # shipped with the image / repo
└── custom/    # your templates (volume mount or local edits)
```

Both trees are walked recursively up to **10 levels deep**, so you can group
templates however you like (`custom/databases/my-tpl.tpl`, etc.).

**`custom/` always wins.** If a file with the same bare name exists in both
trees, the one under `custom/` is used, so you can override any shipped
default without editing the image. Only the first match is used.

`UFW_TEMPLATES_DIR` resolution:

1. `$UFW_TEMPLATES_DIR` env var, if set.
2. `templates/` directory next to the script (useful when running from a repo
   checkout or a standalone install that keeps templates alongside the binary).
3. `/usr/local/share/ufw-manager/templates` (Docker image layout and the
   recommended standalone install path).

## Docker

The Docker image bakes `src/templates/default/` into
`/usr/local/share/ufw-manager/templates/default`. The shipped
`docker-compose.yaml` also bind-mounts a local `./templates` directory over
`custom/`, read-only:

```yaml
volumes:
  - ./templates:/usr/local/share/ufw-manager/templates/custom:ro
```

Drop a `.tpl` file into `./templates/` on the host and it's picked up on the
next `ufw` invocation — no restart needed. Remove it and it's gone. The
directory can be empty or absent; a missing `custom/` just means "no user
templates".

## Standalone (non-Docker)

When running from a git checkout the script auto-detects `src/templates/`
relative to itself, so `./src/ufw-manager pg` works out of the box. For a
system install, either:

- Install templates under `/usr/local/share/ufw-manager/templates/default/`
  (and optionally `custom/`) next to the binary, or
- Point the script at a directory you own:

  ```bash
  export UFW_TEMPLATES_DIR=$HOME/.config/ufw-manager/templates
  sudo -E ufw-manager pg
  ```

Note that `sudo` strips most environment variables by default — use `sudo -E`
or add `Defaults env_keep += "UFW_TEMPLATES_DIR"` to `/etc/sudoers` if you set
the env var globally.

## Examples

**Database with a fixed subnet, no prompts at all:**

```
# custom/office-pg.tpl
allow:5432:1.2.3.4/24:tcp
```

`ufw office-pg` → immediately previews the rule and waits for `[Y/n]`.

**Whitelist the current SSH client IP** (standalone, with `sudo -E`):

```
# custom/me-ssh.tpl
allow:22:$1:tcp
$1=echo "${SSH_CLIENT%% *}"
```

`sudo -E ufw-manager me-ssh` pre-fills `$1` with the IP you're SSH'd in from.

**Multi-placeholder (port + ip):**

```
# custom/dyn.tpl
allow:$1:$2:tcp
```

`ufw dyn 8080 1.2.3.4` → `allow proto tcp from 1.2.3.4 to any port 8080`.
With no args, both fields fall through to the wizard prompts.

**Override a shipped default:**

```
# custom/pg.tpl
allow:5432:10.0.0.0/8:tcp
```

Now `ufw pg` uses the locked-down version instead of the prompting default.
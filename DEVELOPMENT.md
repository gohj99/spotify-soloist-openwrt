# Development notes

## What this package is

Two OpenWrt packages that run Spotify Soloist as a service:

| Package | Role |
|---|---|
| `spotify-soloist` | procd service, updater, expiry checker, audio helper, UCI config |
| `luci-app-spotify-soloist` | LuCI page; contains no logic of its own |

The Soloist binary is **not** in either package. Spotify asks that the archives
not be redistributed, so `/usr/bin/spotify-soloist-updater` downloads them on the
device. That download is also what handles the 90-day build expiry.

## Layout

```
spotify-soloist/
├── Makefile
└── files/
    ├── etc/
    │   ├── config/spotify-soloist          UCI defaults
    │   ├── init.d/spotify-soloist          procd service
    │   └── spotify-soloist/sha256          optional pinned hashes
    └── usr/
        ├── bin/
        │   ├── spotify-soloist-updater     download + verify + install
        │   ├── spotify-soloist-check       what cron runs
        │   ├── spotify-soloist-set-key     store the API key at 0600
        │   ├── spotify-soloist-status      JSON status for LuCI
        │   └── spotify-soloist-audio       card -> sink resolution
        └── lib/spotify-soloist/common.sh   shared helpers

luci-app-spotify-soloist/
├── Makefile
├── luasrc/
│   ├── controller/spotify-soloist.lua      routes + JSON API
│   ├── model/cbi/spotify-soloist.lua       the form
│   └── view/spotify-soloist/
│       ├── status.htm                      live status block
│       └── keyfield.htm                    API key field
└── root/usr/share/rpcd/acl.d/luci-app-spotify-soloist.json
```

`.dev/` holds the test scripts. They are development tools, not part of either
package.

## Where the facts came from

Everything the code does is traceable to a verified source. Before changing
anything, read [docs/soloist-reference.md](docs/soloist-reference.md) — it
records the exact `--help` output, the download URLs, the exit codes, the
`NEEDED` shared libraries of all three architectures, and the startup log format.

The short version of what was verified rather than assumed:

- the real flags (there is no `--bitrate`, `--log-level`, `--cache-size-limit` or
  `--enable-volume-normalisation`)
- the real archive URLs under `soloist-builds.spotifycdn.com`, with stable names
- the build timestamp inside `soloist --version` is a Unix epoch, which is how
  expiry is computed without parsing logs
- **no build links ALSA or JACK**, so audio must go through a sound server
- the binaries are glibc-only, which is the package's central constraint

## Testing

There is no CI and the package has not been built with the OpenWrt SDK. What has
actually been run:

```bash
# POSIX syntax of every shell script
dash -n spotify-soloist/files/usr/bin/* \
        spotify-soloist/files/usr/lib/spotify-soloist/common.sh \
        spotify-soloist/files/etc/init.d/spotify-soloist

# Lua syntax
luac5.1 -p luci-app-spotify-soloist/luasrc/controller/spotify-soloist.lua
luac5.1 -p luci-app-spotify-soloist/luasrc/model/cbi/spotify-soloist.lua

# Functional test of the scripts against a real Soloist binary, in a sandbox
# that mimics the OpenWrt paths. Needs a Linux host with a downloaded binary
# at /tmp/sol/soloist.
bash .dev/functest.sh
```

`.dev/functest.sh` is the one that matters: it builds a fake root, drops the real
binary in, stubs `/lib/functions.sh`, and checks that the status script emits
valid JSON with real values and that the date arithmetic is correct.

`.dev/selftest.sh` is the on-device counterpart. Copy it to a router and run it
there; it reports package, file, libc, expiry, audio and service state, and
distinguishes warnings from failures rather than printing a blanket "PASSED".

### What has not been tested

- building either package with the OpenWrt SDK or `feeds/luci`
- installing on real hardware
- pairing with a real Spotify account
- an actual update cycle
- the LuCI pages in a browser

Treat the first build as the real test.

## Things that are easy to get wrong

These were each mistakes made while writing this, recorded so they are not
repeated:

**`config_load`/`config_get` are not available everywhere.** They live in
`/lib/functions.sh`, which `/etc/rc.common` sources but a bare script under
`/usr/bin` does not. `common.sh` sources it explicitly for that reason.

**POSIX arithmetic has no ternary.** `${x ? y : z}` is a C construct; shell
arithmetic uses an `if`. This broke the date conversion.

**`NamedSection` takes the section name first, then the type** —
`m:section(NamedSection, "main", "spotify-soloist", ...)`. Passing the type first
silently renders nothing.

**`procd_set_param env` takes `VAR=value` pairs**, not two arguments. It builds a
JSON object, so `env PULSE_SERVER unix:...` produces a key with no value.

**`respawn` is three numbers**: `threshold timeout retry`. An instance that dies
within `threshold` seconds counts as a crash, `timeout` is the delay before the
restart, and after `retry` consecutive crashes procd gives up — but only if
`retry` is non-zero, because `0` means retry forever. The package uses
`respawn 3600 5 5`: a crash inside the first hour counts, restart after five
seconds, and give up after five in a row. Retrying forever is wrong here because
Soloist exits 1 on a bad API key or an unwritable data directory, and neither
condition resolves itself.

**Busybox does not ship everything.** `od`, `pkill`, `stat` and `paste` are all
`default n` in OpenWrt's busybox config. Anything relying on them has to guard
with `command -v` and degrade gracefully. `pgrep`, `pidof`, `flock`, `sha256sum`
and the usual coreutils are `y` and safe.

**The API key must not go through a shell argument.** It would be visible in
`ps`. `spotify-soloist-set-key` reads it from a file instead.

**procd `user` is a primary gid, not a group list.** Supplementary groups come
from `initgroups()` against `/etc/group`, which is why the package uses
`USERID:=soloist=soloist:audio=29,pulse` rather than passing groups to procd.

## Style

- Shell: POSIX `sh`, no bash-isms. OpenWrt has no bash by default.
- Lua: the LuCI conventions — tabs, `local` everywhere, `translate()` for user
  text.
- Comments explain *why*. The *what* is in the code.
- Never log or print the API key.

## Adding a configuration option

1. Add the `option` with a comment to `files/etc/config/spotify-soloist`
2. Read it in the init script with `config_get`, and either add a flag or set an
   environment variable
3. Add the field to `luasrc/model/cbi/spotify-soloist.lua` with a sensible
   `default` and `datatype`
4. If the UI needs it, add it to `spotify-soloist-status` and render it in
   `status.htm`
5. Update the tables in `README.md`, `README_EN.md` and
   `docs/soloist-reference.md`

## Adding a LuCI action

1. `entry({"admin","services","spotify-soloist","<name>"}, post("action_<name>"))`
   in the controller
2. Add the action to `write.file` in the rpcd ACL, or it will be denied
3. Call it from `status.htm` with the `token` field included, since `post()`
   handlers are CSRF-checked

## Debugging

```bash
logread -f | grep -i soloist          # live
/etc/init.d/spotify-soloist info      # version, expiry, endpoint
/usr/bin/spotify-soloist-status       # what LuCI sees, as JSON
cat /tmp/spotify-soloist/build.txt    # cached expiry
cat /tmp/spotify-soloist/update.log   # last update run
```

For a permission problem, set `run_as_root=1`, confirm it works as root, then
work out which group membership is missing. Do not leave it on.

## Licence

MIT for the code here. The Soloist binary is Spotify's and proprietary.

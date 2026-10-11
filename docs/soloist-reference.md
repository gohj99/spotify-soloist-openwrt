# Spotify Soloist: verified reference

Everything in this document was confirmed against the shipped binaries and
Spotify's documentation, not inferred. Where something could not be confirmed it
says so explicitly.

The binary used for verification was the release current on 2026-10-11:

```
soloist 1.3.9.9 build 1791676872 (20261011) (g440165f200) (linux/x86_64)
```

## Contents of the release archives

Each archive contains the executable and nothing else that matters:

| File | Notes |
|---|---|
| `soloist` | the executable, mode `0444` in the archive |
| `CHANGELOG.md` | release notes |
| `THIRD_PARTY_LICENSES.txt` | license texts |

## Download URLs

Stable archive names, so these URLs always serve the newest build:

| `uname -m` | Archive | URL |
|---|---|---|
| `aarch64`, `arm64` | `soloist_release_arm64.tar.gz` | `https://soloist-builds.spotifycdn.com/soloist_release_arm64.tar.gz` |
| `armv7l`, `armv6l` | `soloist_release_arm32.tar.gz` | `https://soloist-builds.spotifycdn.com/soloist_release_arm32.tar.gz` |
| `x86_64` | `soloist_release_x86_64.tar.gz` | `https://soloist-builds.spotifycdn.com/soloist_release_x86_64.tar.gz` |

Notes:

- **No checksums or signatures are published.** There is no manifest, no
  `.sha256`, no signature file. Content verification is therefore limited to
  executing the candidate before installing it, or pinning a hash you took
  yourself (see `/etc/spotify-soloist/sha256`).
- **Spotify asks that the archives not be redistributed** and that users be
  pointed at the download page instead. This is why the package downloads the
  binary on the router rather than shipping it.
- The archives are around 12--14 MB and expand to roughly 28--36 MB.
- `Last-Modified` on the CDN responses tracks the newest build, which makes it
  usable as a cheap "has anything changed" probe.

## Complete command line

Taken from `soloist --help` on the real binary:

```
soloist -n <name> -k <key> [options]
soloist ctl <command> [options]
```

| Flag | Argument | Default | Meaning |
|---|---|---|---|
| `-h`, `--help` | | | print help |
| `-n`, `--device-name` | name | **required** | Spotify Connect device name |
| `-k`, `--api-key` | key | **required** | developer API key |
| `-D`, `--data-dir` | path | see below | persistent state: device identity, stored session, crash reports |
| `-C`, `--cache-dir` | path | see below | volatile playback cache |
| `-z`, `--cache-size` | MB | unlimited | must be `0` or at least `100` |
| `-d`, `--pipewire-device` | device | system default | PipeWire node name or id |
| `-i`, `--initial-volume` | 0--100 | `40` | startup volume |
| `-w`, `--ws` | `addr:port` | **disabled** | enable the WebSocket API; port `0` picks a free port |
| `-s`, `--single-track` | URI | | play one URI and exit |
| `-p`, `--pair` | | | authenticate and exit |
| `-v`, `--verbose` | | off | verbose logging |
| `-V`, `--version` | | | print version and exit |

Directory defaults resolve in this order:

- data dir: `$STATE_DIRECTORY`, then `$XDG_DATA_HOME/soloist`, then
  `~/.local/share/soloist`
- cache dir: `$CACHE_DIRECTORY`, then `$XDG_CACHE_HOME/soloist`, then
  `~/.cache/soloist`

`--pair` and `--single-track` are mutually exclusive.

### Flags that do not exist

Worth recording, because they are easy to assume: there is **no** `--bitrate`,
no `--log-level`, and no `--enable-volume-normalisation`. Audio quality is not
configurable.

Note that `-d`/`--pipewire-device` **does** exist and is the supported way to
route audio, but it applies only when Soloist is using PipeWire. For PulseAudio
there is no equivalent flag; `PULSE_SINK` is PulseAudio's own client setting and
is honoured by libpulse (confirmed in PulseAudio's `client-conf.c`, which defines
`ENV_DEFAULT_SINK "PULSE_SINK"`).

## Runtime files in the data directory

| File | Contents |
|---|---|
| `soloist.pid` | daemon pid |
| `.device_id` | stable device identity, keep this |
| `.lock` | instance lock; a stale one makes the next start look like a duplicate |
| `ws.addr` | WebSocket bind address, written when `--ws` is given |
| `ws.port` | actual listening port |
| `crashpad/` | local crash reports |
| `cache/` | per-playback cache |

`ws.addr` and `ws.port` are removed on shutdown, so their presence means the
daemon is up.

## Exit codes

| Code | Meaning |
|---|---|
| `0` | success, including `--help`, `--version`, `--pair`, `--single-track`, and normal shutdown |
| `1` | general failure: bad arguments, missing required option, bad URI, unwritable data or cache dir, **another instance already using the data directory**, invalid build timestamp, startup failure |
| `10` | **the build has expired** |

`ctl` has its own codes: `0` success, `1` bad arguments, `2` connection failed,
`3` server error such as not logged in.

## Expiry

Builds expire **90 days after the build date**, after which the daemon exits
with code `10`.

There is no "days remaining" command or JSON field. The expiry date has to be
derived from `--version`:

```
soloist 1.3.9.9 build 1791676872 (20261011) (g440165f200) (linux/x86_64)
```

- the integer after `build` is a Unix timestamp: `1791676872` is
  `2026-10-11T00:01:12Z`
- the parenthesised `20261011` is the same date in `YYYYMMDD`

Add 90 days to either and you get the expiry moment (`2027-01-09` for this
build). `common.sh` implements exactly this, using the timestamp when present
and the date as a fallback, with pure shell arithmetic so it does not depend on
`date -d`.

At startup the daemon logs the remaining lifetime itself:

```
2026-10-11 09:52:10.434: soloist 1.3.9.9 build 1791676872 (20261011) (g440165f200) (linux/x86_64)
2026-10-11 09:52:10.434: client expires in 89 days
```

which is a useful cross-check but not something to parse in production.

## Startup log, verbatim

```
2026-10-11 09:52:10.434: soloist 1.3.9.9 build 1791676872 (20261011) (g440165f200) (linux/x86_64)
2026-10-11 09:52:10.434: client expires in 89 days
2026-10-11 09:52:10.496: api: websocket server listening on 127.0.0.1:9090
2026-10-11 09:52:10.496: ready, device_name=Test Speaker device_id=c3f0e205-53e8-43f6-8e28-512b89000118
2026-10-11 09:52:10.497: waiting for login — connect to "Test Speaker" from your Spotify app
2026-10-11 09:52:10.498: running
```

## `soloist ctl`

```
soloist ctl <command> [options]
```

Commands: `status`, `now [--json]`, `queue [n]`, `trace`, `play [uri]`, `pause`,
`next`, `prev`, `seek <ms>`, `volume <0-100>`, `shuffle <on|off>`,
`repeat <off|context|track>`, `add-to-queue <uri>`, `activate`, `deactivate`.

Options: `-D, --data-dir`, `-w, --ws addr:port`, `-h, --help`.

Real output, captured while the daemon ran with `--ws 127.0.0.1:9090`:

```
$ soloist ctl -D /tmp/solrun/d status
soloist: running (pid 1128)
  ws: listening on 127.0.0.1:9090
  logged in: no
```

`ctl` discovers the daemon through the data directory by default. Note that
observe and control commands need `--ws` to have been given at startup; without
it `ctl status` still works but the rest cannot connect.

## Shared library requirements

Resolved from the ELF headers of all three published binaries:

| Build | Interpreter | `NEEDED` |
|---|---|---|
| arm64 | `/lib/ld-linux-aarch64.so.1` | `libm`, `libpthread`, `libdl`, `libatomic`, `librt`, `libgcc_s`, `libc` |
| arm32 | `/lib/ld-linux-armhf.so.3` | `libm`, `libpthread`, `libdl`, `libatomic`, `librt`, `libc` |
| x86_64 | `/lib64/ld-linux-x86-64.so.2` | `libm`, `libatomic`, `libc` |

All three are dynamically linked against **glibc** (arm32 is hard-float) and the
highest symbol version referenced is `GLIBC_2.38`.

Loaded at runtime via `dlopen`, so not listed as `NEEDED`:

- `libpipewire-0.3.so.0` — Spotify's own PipeWire integration
- `libpulse.so.0` — the PulseAudio client, with `pa_context_connect` present

**No build references ALSA or JACK at all.** There is no `libasound`, no
`snd_pcm`, and no `libjack` string anywhere in any of the three binaries. This
is the single most important constraint on audio configuration, and it is
covered in [audio-output.md](audio-output.md).

## Environment variables the binary reads

Confirmed as strings inside the executable:

`STATE_DIRECTORY`, `CACHE_DIRECTORY`, `XDG_DATA_HOME`, `XDG_CACHE_HOME`,
`XDG_CONFIG_HOME`, `PIPEWIRE_CONFIG_DIR`, and (via the PulseAudio client
library) `PULSE_SERVER`, `PULSE_COOKIE`, `PULSE_SINK`.

## The WebSocket API

Enabled with `--ws addr:port`. It has **no authentication, no authorization, no
TLS, no origin validation and no CSRF protection** — Spotify's own
documentation says so plainly. It is a local integration surface only.

Discovery: `ws.addr` and `ws.port` in the data directory.

On connect the server sends `auth_state`; if already logged in it also sends
`playback_state`. Every client message is
`{"type":"command","command":"..."}`. Events carry a `type`.

Query commands — `get_auth_state` (no login needed), `get_state`, `get_queue`
(with an optional `limit`).

Control commands — `play` (optional `uri`), `pause`, `skip_next`, `skip_prev`,
`seek` (`position_ms`), `set_volume` (`volume`), `set_shuffle` (`enabled`),
`set_repeat_context` (`enabled`), `set_repeat_track` (`enabled`),
`add_to_queue` (`uri`), `activate`, `deactivate`.

The `playback_state` payload carries `status` (`idle`/`playing`/`paused`/
`buffering`), `item`, `context`, `position`, `volume`, `is_active`, `options`
(`shuffle`, `repeat`, `playback_speed`, `modes`) and `available_actions`.
Entities are wrapped in a common envelope with `uri`, `entity_type` and a
`decorations` object holding `identity.name`, `visual_identity.cover[]`,
`parent`, `creators` and `playback.duration_ms`.

## Authentication and accounts

Soloist needs an API key, and Spotify only issues one to a **Premium** account,
even though the client can play Free accounts once paired. Generate it at
`developer.spotify.com/dashboard/soloist`. The key is tied to the account that
created it and Spotify says not to share it.

Pairing happens through the normal Spotify Connect flow: start the daemon, open
the Spotify app on the same network, pick the device named by `--device-name`,
and start playback. The resulting session is stored in the data directory, which
is why that directory has to survive reboots.

Spotify's own caution about the key applies to `ps`: passing it as a command line
argument exposes it to anything that can read the process table. On OpenWrt that
is a smaller problem than on a multi-user machine, but it is still why the key
lives in a `0600` file and is not stored in UCI.

## Sources

- <https://developer.spotify.com/documentation/soloist/tutorials/getting-started>
- <https://developer.spotify.com/documentation/soloist/reference/command-line>
- <https://developer.spotify.com/documentation/soloist/reference/downloads-and-updates>
- <https://developer.spotify.com/documentation/soloist/reference/websocket-api>
- <https://developer.spotify.com/documentation/soloist/reference/soloist-ctl>
- direct inspection of `soloist_release_{arm64,arm32,x86_64}.tar.gz`

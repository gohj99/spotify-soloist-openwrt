# Changelog

## 1.0.0 — unreleased

First version that matches the real Spotify Soloist binary.

### Note on this release

An earlier draft of this project was written without reading Spotify's
documentation or inspecting the binaries. It invented command line flags
(`--cache-size-limit`, `--bitrate`, `--enable-volume-normalisation`,
`--log-level`), invented download URLs, and documented options that Soloist does
not have (bitrate, volume normalisation, direct ALSA output). It also claimed a
test suite passed when nothing had been run.

That draft has been discarded. Every flag, exit code, download URL and library
requirement in this release was verified by downloading the published archives and
running the binary. The verification is recorded in
[docs/soloist-reference.md](docs/soloist-reference.md), and the code was rewritten
from that reference.

### Features

**Service packaging**

- procd service with UCI configuration
- runs as an unprivileged `soloist` user, added to the `audio` and `pulse`
  groups, with a `run_as_root` escape hatch for diagnosis
- the API key is stored in `/etc/spotify-soloist/api-key` at mode `0600` rather
  than in UCI, and is passed to the daemon through a file rather than a shell
  argument
- refuses to start an expired build, so procd does not respawn it forever
- reports the specific reason a start failed instead of failing silently

**90-day expiry handling**

- build timestamp parsed from `soloist --version`, using pure shell date
  arithmetic so it does not depend on `date -d`
- weekly cron check with a configurable threshold (default 15 days)
- downloads to a staging directory, verifies, then installs atomically
- keeps the previous binary and restores it if the new build does not stay up
- a deadman timer rolls back an update that outlives the request that started it
- the LuCI page warns at 30 and 15 days

**Verification before installing**

- rejects an implausibly small download
- confirms the archive contains a `soloist` executable
- checks the ELF machine type against the running architecture
- executes the candidate with `--version` and validates the output, which is
  what catches a wrong architecture and missing shared libraries
- refuses an already-expired build
- optional hash pinning via `/etc/spotify-soloist/sha256` for anyone who wants
  reproducibility more than automatic updates

**Audio**

- resolves an ALSA card (`hw:N`) to the sound server's sink name and applies it
  as `PULSE_SINK` for the daemon only
- sets `PULSE_SERVER`, `PULSE_COOKIE` and `XDG_RUNTIME_DIR` for a system-mode
  PulseAudio, including the cookie permissions a group member needs
- PipeWire support with `XDG_RUNTIME_DIR`/`PIPEWIRE_RUNTIME_DIR` and
  `--pipewire-device`
- refuses to start when no sound server is installed, rather than playing into
  nothing

**LuCI**

- status page: running state, installed build, days remaining with colour
  warnings, device name, sound server, login state, endpoint, architecture
- start/stop/restart, one-click update with progress polling, update log viewer
- API key field, stored out of band and never displayed again
- output device list read from `/proc/asound/cards`
- dynamic warnings when no sound card, no sound server, or a downstream
  scheduled task is missing

**Documentation**

- `docs/soloist-reference.md` — verified flags, exit codes, URLs, library
  requirements, WebSocket API
- `docs/limitations.md` — the glibc/musl problem and everything else that will
  not work
- `docs/audio-output.md` — USB DAC, 3.5 mm jack, HDMI, and why ALSA is not an
  option
- `docs/architecture.md` — component and data flow

### Known limitations

See [docs/limitations.md](docs/limitations.md). The significant ones:

- **glibc only.** No OpenWrt release target uses glibc, so the package is
  unavailable on stock images by design.
- **No checksums from Spotify**, so content verification is limited to executing
  the candidate unless you pin a hash yourself.
- **The expiry cannot be bypassed.** The router needs internet access at least
  once every 90 days.
- **One instance per data directory.** Multiple daemons need separate data
  directories, device names and ports, managed by hand.
- **PipeWire has no OpenWrt package**, so PulseAudio is the practical backend.
- **Not tested on hardware.** All shell and Lua code has been syntax-checked and
  the scripts run against a real binary, but the package has not been built with
  the OpenWrt SDK nor installed on a device.

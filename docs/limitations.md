# Limitations, and the musl problem

This is the most important document in the repository. Read it before deciding
whether this package is right for your router.

## The core problem: Spotify ships glibc builds only

Spotify publishes exactly three Linux builds of Soloist, and all three are
dynamically linked against **glibc**:

| Build | Interpreter | Highest symbol version |
|---|---|---|
| arm64 | `/lib/ld-linux-aarch64.so.1` | `GLIBC_2.38` |
| arm32 (hard-float) | `/lib/ld-linux-armhf.so.3` | `GLIBC_2.38` |
| x86_64 | `/lib64/ld-linux-x86-64.so.2` | `GLIBC_2.38` |

**OpenWrt uses musl, not glibc.** Musl is the default libc for every released
OpenWrt target, and no released target overrides it — the `USE_GLIBC` symbol
exists in the tree, but nothing outside the toolchain selects it.

A musl system has no `/lib/ld-linux-aarch64.so.1`, no `libc.so.6` with
`GLIBC_2.38` symbols, and no drop-in substitute for them. So on a stock OpenWrt
image the Soloist binary cannot execute at all. It is not a missing-library
problem that installing another package fixes:

```
$ ./soloist --version
bash: ./soloist: No such file or directory
```

That error is misleading — the file is there. It is the *interpreter* named in
its ELF header that is missing.

### What this means for the package

The package is declared with:

```
DEPENDS:=@(!USE_MUSL||BROKEN)
```

so on a musl target it is marked unavailable and cannot be installed. That is
deliberate: installing a service that can never start is worse than not offering
it. The updater also verifies a candidate by executing it before installation and
refuses to install a binary that will not run, with a message naming glibc as the
likely cause.

### Your options

| Option | Work |
|---|---|
| Build a glibc OpenWrt image | Set `CONFIG_USE_GLIBC`, i.e. `make menuconfig → Advanced configuration → Toolchain → Toolchain libc → glibc`. Also needs `TOOLCHAINOPTS`. Expect to build and maintain the whole image yourself. |
| Run Soloist on a non-OpenWrt Linux host | A Raspberry Pi running Raspberry Pi OS (which is glibc) is what Spotify tested against; glibc 2.41 was their reference. Keep OpenWrt as the router and put Soloist somewhere else on the LAN. |
| Use a different Spotify Connect client | `librespot` builds against musl and runs on OpenWrt normally. It is a clean-room reimplementation rather than Spotify's own engine, so it is a different product, but it works. |
| Use `owntone` or `shairport-sync` | Both are in the feed and need no glibc, but they implement AirPlay rather than Spotify Connect. |

There is no gcompat-style shim in the OpenWrt feeds, and even where such shims
exist they generally do not cover the whole surface a Rust/C++ binary with
`GLIBC_2.38` requirements touches.

### Why the package exists anyway

Because the wrapper, the configuration model, the expiry handling and the LuCI
page are all useful the moment the binary can run — on a glibc image, or if
Spotify ever publishes a musl or static build. Nothing in this package depends on
glibc itself; only the downloaded binary does.

## Other limitations

### No checksum or signature to verify against

Spotify publishes no hashes and no signatures for the archives. The download URL
always serves whatever build is current. The updater therefore cannot prove that
what it downloaded is what Spotify built. What it does instead:

1. refuses an implausibly small download
2. extracts and confirms the archive really contains a `soloist` executable
3. checks the ELF machine type matches the running architecture
4. executes it with `--version` and checks the output
5. rejects a build that is already expired

This catches wrong architecture, truncated downloads and missing libraries. It
does **not** catch a substituted payload served by a compromised mirror.

The only way to close that gap is to pin a hash you took yourself in
`/etc/spotify-soloist/sha256`. The cost is that a pinned build carries its own
expiry date, so the pin has to be refreshed every 90 days — which defeats the
point of automatic updates. Choose per device.

`ca-bundle` is a dependency so the download is at least authenticated by TLS.

### Builds expire every 90 days, by design

There is no way around it. The daemon exits with code `10` once the build is 90
days old, and Spotify's stated intent is that you install a newer build before
that happens. Nothing in this package bypasses the check, and nothing can.

What the package does is make the expiry survivable:

- the init script **refuses to start an expired build**, so procd does not
  respawn a corpse every five seconds
- a weekly cron job (`17 4 * * 0`) checks the remaining time
- with `auto_update` on, it downloads and installs a fresh build once 15 days
  remain, restarting the service only if the new build comes up cleanly
- the LuCI page shows the remaining days with a colour warning at 30 and 15 days

Practical consequence: **if the router is offline for a long period, the speaker
will stop.** The update has to happen before expiry, and the build has to be
downloaded from the internet.

### A failed update is survivable, once

The updater keeps the previous binary in `/tmp` and restores it if the new build
does not stay up. That copy is in RAM, so a reboot between a failed update and
the rollback loses it. In that case the daemon simply will not start, and the
fix is to run the updater again:

```bash
/usr/bin/spotify-soloist-updater --force
/etc/init.d/spotify-soloist restart
```

A long download can also outlive the HTTP request that started it. The LuCI page
handles this by polling: the update is detached, and an internal "deadman" timer
rolls the installation back and restarts the old build if the updater never
finishes.

### Only one instance per data directory

Soloist takes a lock in the data directory. A second process pointed at the same
directory exits with code `1`, "another instance already using the data
directory". Running two Soloist daemons on one router means giving each its own
`data_dir`, `cache_dir`, device name and WebSocket port. The package does not
model multiple instances; doing this by hand means not using the init script.

A stale `.lock` after an unclean shutdown is handled: `stop_service()` removes it.

### The API key needs a Premium account

Spotify only issues a Soloist API key to a **Premium** account. The client can
*play* a Free account once paired, but you cannot generate the key without
Premium. This is a Spotify policy, not a technical limit this package can work
around.

### No Swift/FFmpeg-style codec options

Audio quality is not configurable — there is no bitrate flag. Some content may
fail to decode depending on how Spotify's engine handles it; the arm64 build's
string table references FFmpeg bitstream filters, so it carries its own
assumptions about media. Nothing here exposes that.

### The WebSocket API is unauthenticated

By design. No auth, no TLS, no origin checks. It is meant for local integration
on one machine. The package defaults it to **off**, and to `127.0.0.1` when
enabled. Enabling it on `0.0.0.0` exposes playback control and the currently
playing track to anyone who can reach the port.

### Raspberry Pi is the only tested platform

Spotify's reference was a Raspberry Pi 3 Model A+ on Raspberry Pi OS
(Trixie-based, glibc 2.41). Anything else is untested by them. Combined with the
glibc requirement, it means the well-trodden path is: Soloist on a Pi, not on the
router.

## Summary for a would-be user

- On a **stock OpenWrt image** (musl): this will not work. Use `librespot`
  instead, or move Soloist to a glibc machine.
- On a **glibc OpenWrt image** you build yourself: it should work, and the
  package handles the expiry, the audio server plumbing and the configuration.
- Either way, **something has to run the update within 90 days** of each build,
  and something has to be running as a sound server for audio to come out at all.

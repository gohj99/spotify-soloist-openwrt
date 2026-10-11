# Spotify Soloist for OpenWrt

Run [Spotify Soloist](https://developer.spotify.com/documentation/soloist) — the
headless build of Spotify's own playback engine — as a service on OpenWrt, with a
LuCI page for configuration.

---

## Read this first

**Spotify publishes glibc builds only, and OpenWrt uses musl.** On a stock
OpenWrt image the Soloist binary cannot execute, so this package is marked
unavailable there and cannot be installed.

It works on:

- an OpenWrt image you build yourself with `CONFIG_USE_GLIBC=y`, or
- any glibc Linux host (a Raspberry Pi running Raspberry Pi OS is what Spotify
  tested against).

If you are on stock OpenWrt and want Spotify Connect, use `librespot` instead —
it builds against musl and runs normally. Details and the full list of options
are in [docs/limitations.md](docs/limitations.md).

Separately, **Soloist cannot talk to a sound card directly.** No build links
ALSA or JACK; audio goes through PipeWire or PulseAudio. See
[docs/audio-output.md](docs/audio-output.md) — including how to route to a USB
DAC or the 3.5 mm jack.

---

## What it does

- Runs Soloist under procd, with the configuration expressed in UCI
- Stores the API key as a `0600` file rather than in world-readable config
- Handles the **90-day build expiry**: a scheduled check downloads a fresh build
  before the old one stops working, and the init script refuses to start an
  expired binary so procd does not respawn it forever
- Resolves the attached sound card to the sound server's sink name, so choosing
  an output is one setting
- Shows status, remaining lifetime and the update log in LuCI

## Packages

| Package | Contents |
|---|---|
| `spotify-soloist` | service wrapper, updater, expiry checker, audio helper, UCI config |
| `luci-app-spotify-soloist` | the LuCI page; depends on the above |

The binary itself is **not** in either package. Spotify asks that the archives
not be redistributed, so the updater downloads them on the device.

## Install

Build with the OpenWrt SDK:

```bash
SDK_PATH=/path/to/openwrt-sdk ./build.sh
```

Then either use `./install.sh`, or copy the `.ipk` files across and:

```bash
opkg install /tmp/spotify-soloist_*.ipk
opkg install /tmp/luci-app-spotify-soloist_*.ipk
```

## Configure

Soloist needs an API key, which requires a **Spotify Premium** account. Generate
one at <https://developer.spotify.com/dashboard/soloist>.

Then in LuCI, under **Services → Spotify Soloist**:

1. Paste the API key
2. Tick **Enable Spotify Soloist**
3. Pick the output device under **Audio output**
4. Save & Apply

The binary downloads on first start.

From the command line instead:

```bash
echo 'YOUR_API_KEY' > /tmp/k
/usr/bin/spotify-soloist-set-key /tmp/k

uci set spotify-soloist.main.enabled='1'
uci set spotify-soloist.main.device_name='Kitchen'
uci set spotify-soloist.main.alsa_output='hw:1'
uci commit spotify-soloist

/etc/init.d/spotify-soloist enable
/etc/init.d/spotify-soloist start
```

## Use

Open the Spotify app on the same network, play something, tap the device picker,
and choose the name you configured. The device has to be paired once this way;
the session then lives in the data directory.

## Commands

```bash
/etc/init.d/spotify-soloist start|stop|restart|enable|disable
/etc/init.d/spotify-soloist info          # version, expiry, endpoint
/usr/bin/spotify-soloist-updater          # download the current build now
/usr/bin/spotify-soloist-updater --check  # report status without changing anything
/usr/bin/spotify-soloist-check            # what cron runs
/usr/bin/spotify-soloist-check --days     # remaining days on the current build
/usr/bin/spotify-soloist-audio --list     # sound cards and sinks
```

## Configuration reference

| Option | Default | Meaning |
|---|---|---|
| `enabled` | `0` | start the service |
| `device_name` | hostname | name in the Spotify Connect picker |
| `require_pair` | `0` | run once in pairing mode then stop |
| `audio_backend` | `auto` | `auto`, `pulseaudio` or `pipewire` |
| `alsa_output` | `auto` | which sound card to play from, e.g. `hw:1` |
| `pipewire_device` | — | PipeWire node, overrides the above on PipeWire |
| `initial_volume` | `40` | volume at startup, 0–100 |
| `data_dir` | `/etc/spotify-soloist/data` | identity and paired session — keep it |
| `cache_dir` | `/tmp/spotify-soloist/cache` | playback cache, on tmpfs by design |
| `cache_size` | `0` | cache limit in MB; `0` is unlimited, otherwise ≥ 100 |
| `ws_enabled` | `0` | the WebSocket API |
| `ws_address` | `127.0.0.1` | leave it on loopback |
| `ws_port` | `9090` | `0` picks a free port |
| `auto_update` | `1` | download new builds before they expire |
| `update_threshold` | `15` | days remaining before updating |
| `update_notify_only` | `0` | warn instead of downloading, for metered links |
| `check_update_cron` | `17 4 * * 0` | when the check runs |
| `verbose` | `0` | verbose logging |
| `run_as_root` | `0` | run privileged; a diagnostic, not a fix |

## Documentation

| Document | Contents |
|---|---|
| [docs/limitations.md](docs/limitations.md) | **the musl problem**, expiry, and what will not work |
| [docs/audio-output.md](docs/audio-output.md) | USB DAC, 3.5 mm jack, HDMI, and why ALSA is not an option |
| [docs/soloist-reference.md](docs/soloist-reference.md) | every verified flag, exit code and download URL |
| [docs/architecture.md](docs/architecture.md) | how the pieces fit together |
| [QUICKSTART.md](QUICKSTART.md) | the short version |
| [DEVELOPMENT.md](DEVELOPMENT.md) | build and test notes |

## Documentation honesty

An earlier draft of this project described flags that do not exist
(`--cache-size-limit`, `--bitrate`, `--enable-volume-normalisation`,
`--log-level`) and invented download URLs, because it was written without reading
Spotify's documentation or the binaries. Everything in
[docs/soloist-reference.md](docs/soloist-reference.md) has since been verified
against the shipped binaries and the official pages, and the code has been
rewritten to match. Where something could not be verified, it is marked as such
rather than guessed.

## Licence

MIT for the wrapper code in this repository. The Soloist binary is Spotify's,
proprietary, and governed by their terms — this repository neither contains nor
redistributes it.

# Spotify Soloist for OpenWrt

Run [Spotify Soloist](https://developer.spotify.com/documentation/soloist) as a
service on OpenWrt, with a LuCI configuration page.

[中文文档](README.md) | **English**

---

## Read this first

**Spotify publishes glibc builds only; OpenWrt uses musl.** On a stock OpenWrt
image the Soloist binary cannot execute, so this package is marked unavailable
there and cannot be installed.

It works on an OpenWrt image built with `CONFIG_USE_GLIBC=y`, or on any glibc
Linux host — Spotify's own reference was a Raspberry Pi on Raspberry Pi OS. On
stock OpenWrt, `librespot` is the working alternative. See
[docs/limitations.md](docs/limitations.md).

Also note **Soloist cannot talk to a sound card directly**: no build links ALSA
or JACK, so audio goes through PipeWire or PulseAudio. Routing to a USB DAC or
the 3.5 mm jack is covered in [docs/audio-output.md](docs/audio-output.md).

---

## Features

- Runs Soloist under procd with UCI configuration
- Stores the API key as a `0600` file instead of world-readable config
- Handles the **90-day build expiry**: scheduled updates, plus a refusal to start
  an expired binary so procd does not respawn it indefinitely
- Translates the attached sound card into the sound server's sink name, so
  choosing an output is a single setting
- LuCI page with status, remaining lifetime and the update log

## Packages

| Package | Contents |
|---|---|
| `spotify-soloist` | service wrapper, updater, expiry checker, audio helper, UCI config |
| `luci-app-spotify-soloist` | the LuCI page; depends on the above |

The binary is not bundled — Spotify asks that the archives not be redistributed,
so it is downloaded on the device.

## Installation

```bash
SDK_PATH=/path/to/openwrt-sdk ./build.sh
./install.sh
```

Or manually:

```bash
scp spotify-soloist_*.ipk luci-app-spotify-soloist_*.ipk root@192.168.1.1:/tmp/
ssh root@192.168.1.1
opkg install /tmp/spotify-soloist_*.ipk /tmp/luci-app-spotify-soloist_*.ipk
```

## Configuration

Get an API key at <https://developer.spotify.com/dashboard/soloist> — this
requires a **Spotify Premium** account.

Then in LuCI under **Services → Spotify Soloist**: paste the key, enable the
service, pick the output device, Save & Apply.

From the shell:

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

## Usage

Open the Spotify app on the same network, play something, and select your device
in the device picker. Pairing is stored in the data directory.

### Commands

```bash
/etc/init.d/spotify-soloist start|stop|restart|enable|disable
/etc/init.d/spotify-soloist info
/usr/bin/spotify-soloist-updater --force
/usr/bin/spotify-soloist-check --days
/usr/bin/spotify-soloist-audio --list
/usr/bin/spotify-soloist-cron show        # the installed schedule
```

## Configuration options

| Option | Default | Meaning |
|---|---|---|
| `enabled` | `0` | start the service |
| `device_name` | hostname | name in the Spotify Connect picker |
| `require_pair` | `0` | run once in pairing mode, then stop |
| `audio_backend` | `auto` | `auto`, `pulseaudio` or `pipewire` |
| `alsa_output` | `auto` | which sound card to play from, e.g. `hw:1` |
| `pipewire_device` | — | PipeWire node name or id (official `--pipewire-device`) |
| `initial_volume` | `40` | volume at startup, 0–100 |
| `data_dir` | `/etc/spotify-soloist/data` | identity and paired session |
| `cache_dir` | `/tmp/spotify-soloist/cache` | playback cache, on tmpfs |
| `cache_size` | `0` | MB; `0` unlimited, otherwise ≥ 100 |
| `ws_enabled` | `0` | the WebSocket API |
| `ws_address` | `127.0.0.1` | leave on loopback |
| `ws_port` | `9090` | `0` picks a free port |
| `auto_update` | `1` | download new builds before expiry |
| `update_threshold` | `15` | days remaining before updating |
| `update_notify_only` | `0` | warn instead of downloading (metered links) |
| `check_update_cron` | `17 4 * * 0` | when the check runs |
| `verbose` | `0` | verbose logging |
| `run_as_root` | `0` | diagnostic only |

## The 90-day expiry

Spotify expires every build 90 days after it was built; an expired build exits
with status `10`. There is no way to bypass this. What the package does:

1. a weekly cron check reads the build timestamp from `soloist --version`
2. once 15 days remain, a fresh build is downloaded and verified
3. the service restarts only if the new build comes up cleanly, otherwise the
   previous binary is restored
4. the LuCI page warns at 30 and 15 days

The requirement this creates: the router needs internet access at least once
every 90 days, or the speaker stops.

## Troubleshooting

```bash
logread | grep -i soloist | tail -30
cat /proc/asound/cards
pactl list short sinks
```

Further detail in [QUICKSTART.md](QUICKSTART.md) and
[docs/limitations.md](docs/limitations.md).

## Documentation

| Document | Contents |
|---|---|
| [docs/limitations.md](docs/limitations.md) | the musl problem, expiry, what will not work |
| [docs/audio-output.md](docs/audio-output.md) | USB DAC, 3.5 mm jack, HDMI |
| [docs/soloist-reference.md](docs/soloist-reference.md) | verified flags, exit codes, download URLs |
| [docs/architecture.md](docs/architecture.md) | how the pieces fit together |
| [QUICKSTART.md](QUICKSTART.md) | the short version |
| [CONTRIBUTING.md](CONTRIBUTING.md) | how to contribute |

## Note on accuracy

An earlier draft of this project documented options that do not exist
(`--bitrate`, `--log-level`, `--enable-volume-normalisation`) and invented
download URLs. Those have been removed. Everything in
[docs/soloist-reference.md](docs/soloist-reference.md) is verified against the
shipped binaries and Spotify's documentation.

## Licence

MIT for the wrapper code here. The Soloist binary is Spotify's, proprietary, and
governed by their terms; it is neither included nor redistributed by this
repository.

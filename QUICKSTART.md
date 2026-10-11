# Quick start

## Before you start

Two things decide whether this can work at all. Check both first.

**1. Is your system glibc?** Spotify ships glibc-only builds and OpenWrt is musl.
On a stock OpenWrt image this will not run:

```bash
ls /lib/ld-linux-*.so.* 2>/dev/null    # a glibc loader means you are fine
```

If that prints nothing, stop and read [docs/limitations.md](docs/limitations.md).
`librespot` is the working alternative on musl.

**2. Is a sound server installed?** Soloist cannot talk to a sound card directly.

```bash
opkg install pulseaudio-daemon pulseaudio-tools alsa-utils
```

## Install

```bash
./build.sh                       # needs SDK_PATH set, see README
./install.sh                     # or copy the .ipk files and use opkg
```

## Get an API key

A **Spotify Premium** account is required. Generate the key at
<https://developer.spotify.com/dashboard/soloist>.

## Configure

In LuCI: **Services → Spotify Soloist**.

1. Paste the API key and save
2. Tick **Enable Spotify Soloist**
3. Choose the output under **Audio output** (the list is read from the hardware)
4. Save & Apply

Or from the shell:

```bash
echo 'YOUR_API_KEY' > /tmp/k
/usr/bin/spotify-soloist-set-key /tmp/k

uci set spotify-soloist.main.enabled='1'
uci set spotify-soloist.main.device_name='Kitchen speaker'
uci commit spotify-soloist

/etc/init.d/spotify-soloist enable
/etc/init.d/spotify-soloist start
```

The binary downloads during the first start. Watch it happen:

```bash
logread -f | grep -i soloist
```

## Pair and play

1. Open Spotify on a device on the same network
2. Play something
3. Tap the device picker and choose the name you configured
4. Audio should come out of the selected output

Pairing is remembered in the data directory, so you only do this once — provided
`data_dir` stays on persistent storage.

## Checking it is healthy

```bash
/etc/init.d/spotify-soloist info         # version, expiry, WebSocket endpoint
/usr/bin/spotify-soloist-check --days    # how long this build has left
```

## Common problems

**Service will not start.** Read the log — the init script reports the specific
reason rather than failing silently:

```bash
logread | grep -i soloist | tail -20
```

The usual causes, in order of likelihood:

- no API key stored yet
- the binary has expired, or is not downloaded
- no sound server installed

**Device is not in the Spotify picker.** Same network, and the router must not
have client isolation or a firewall rule blocking mDNS between subnets.

**No sound.** Almost always the sound server rather than Soloist:

```bash
cat /proc/asound/cards      # is a card even attached?
ps | grep -E 'pulseaudio|pipewire'
pactl list short sinks      # does the server see an output?
```

If a card is attached but the server does not list it, the kernel module for that
card is probably missing. For USB audio that is `kmod-usb-audio`.

**Wrong output (USB DAC vs on-board jack).** Pick the card in the LuCI page and
restart. It is applied per-service, so nothing else on the router is affected.

## What happens after 90 days

Every Soloist build stops working 90 days after its build date. The weekly check
installed with the package downloads a fresh build once 15 days remain. You do
not have to do anything, as long as the router has internet access.

If it does lapse:

```bash
/usr/bin/spotify-soloist-updater --force
/etc/init.d/spotify-soloist restart
```

Full details, including why the expiry cannot be bypassed, are in
[docs/limitations.md](docs/limitations.md).

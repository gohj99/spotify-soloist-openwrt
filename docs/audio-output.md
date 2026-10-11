# Audio output on OpenWrt

## The short version

**Spotify Soloist cannot talk to a sound card directly.** No published build
links ALSA or JACK — verified by reading the ELF headers and string tables of
all three architectures: there is no `libasound`, no `snd_pcm` and no `libjack`
anywhere. Every build only dlopens `libpipewire-0.3.so.0` and `libpulse.so.0`.

That has a direct consequence for the usual "plug a USB sound card into the
router and listen" plan: **you need a sound server running on the router.**
Soloist hands audio to that server, and the *server* decides which card, DAC or
jack it comes out of.

```
Spotify app  --(Spotify Connect)-->  soloist  --(PulseAudio/PipeWire)-->  ALSA  -->  card/DAC/jack
```

So the answer to "can I configure the 3.5 mm jack or a USB DAC?" is yes — but the
setting lives in the sound server, not in Soloist. This package wires the two
together so it still only takes one setting in LuCI.

## What the backends actually are

| Backend | Status on OpenWrt |
|---|---|
| PipeWire | Supported by every Soloist build, but **OpenWrt has no PipeWire package at all** — it is not in the packages feed. Realistic only on a glibc image you build yourself with an out-of-tree PipeWire. |
| PulseAudio | The practical choice. `pulseaudio-daemon` is in the feed and builds for musl. |
| ALSA | **Not supported by Soloist.** Reachable only as PulseAudio's own ALSA sink, which is what happens by default. |
| JACK | Not supported. |

PulseAudio is therefore what this package installs and configures by default.

## Which card the audio comes out of

### The mechanism

ALSA names hardware `hw:0`, `hw:1`, and so on, as listed in
`/proc/asound/cards`. PulseAudio and PipeWire give the same hardware a longer
name such as:

```
alsa_output.platform-xhci-hcd.1.auto-usb-0:1.2:1.0.analog-stereo
alsa_output.pci-0000_00_1f.3.analog-stereo
```

Soloist **does** have an official output-routing flag:

```
-d, --pipewire-device DEVICE    Route audio to a specific PipeWire node name or ID.
```

and it applies only when Soloist is using PipeWire. Spotify's documentation
states this explicitly, and it is on the command-line reference page alongside
`--initial-volume`.

That flag is the whole story for PipeWire. **For PulseAudio there is no
equivalent flag**, which is the gap this package fills: it resolves the ALSA card
to the sound server's sink name and sets `PULSE_SINK` on the daemon.

```
audio_output = hw:1   ->   resolved to   alsa_output.usb-....analog-stereo
                       ->   PULSE_SINK=alsa_output.usb-....analog-stereo
```

`/usr/bin/spotify-soloist-audio --resolve hw:1` does the translation by matching
the ALSA card identifier against the sink names the sound server reports. Because
it is set per-process, **only the Spotify daemon is pinned to that output**;
anything else running on the router keeps using the system default.

On PipeWire the init script prefers the official flag: the value from the LuCI
**PipeWire node** field goes to `--pipewire-device`, and only if that is empty
does it fall back to resolving the ALSA card. So on PipeWire you are using
Spotify's own mechanism, not a workaround.

The LuCI page lists whatever is actually attached, read from
`/proc/asound/cards`, so you pick by description rather than by guessing a sink
name.

### USB sound card

1. Install `kmod-usb-audio` (and `kmod-usb-core`, usually already present).
2. Plug the adapter in and check it appeared:
   ```
   cat /proc/asound/cards
   ```
   It should show up as a second card, typically `hw:1`.
3. In LuCI pick that card under **Audio output → Output device**.
4. Restart the service.

The adapter must be a class-compliant USB audio device (UAC1/UAC2), which is
almost all of them. Cheap ones sometimes present playback and capture as
separate devices; pick the one whose description mentions playback or output.

### On-board 3.5 mm jack

Same procedure, but the card is the SoC's own codec — `hw:0` on most boards.
That requires the kernel module for the specific SoC (for example
`kmod-sound-mt7620` on some MediaTek targets, or the corresponding module from
your target's kernel package list). The jack is also frequently
output-only-after-a-mixer-change: if there is no sound, the codec's output path
may be muted or routed to HDMI by default, and `alsamixer` is the tool for that.

### HDMI

Usually the same card as the analog output, exposed as a separate sink
(`hdmi-stereo` rather than `analog-stereo`).

- On **PipeWire**, name the node in the LuCI **PipeWire node** field and it goes
  straight to `--pipewire-device`. This is the supported path.
- On **PulseAudio**, Soloist has no equivalent flag, so the sink is selected with
  `PULSE_SINK`, which is what the LuCI **Output device** field sets. Both cards
  appear in `/proc/asound/cards`, so pick the one whose description mentions HDMI.

Note that a single ALSA card can expose analog and HDMI as two sinks. The
resolver picks the first sink whose name matches the card, which may not be the
one you wanted. If you hit that, check `pactl list short sinks`, then either set
the exact sink name through the sound server's default or, on PipeWire, use the
node field to be precise.

### Bluetooth

Out of scope here, but worth knowing: a Bluetooth speaker is just another
PulseAudio sink, so `PULSE_SINK` works the same way. You would need
`bluez-daemon` and the avahi variant of PulseAudio.

## Making sure sound comes out at all

The most common failure is not a wrong device but no sound server running. The
init script refuses to start when neither `pulseaudio` nor `pipewire` is
present, and logs:

```
no audio server: install pulseaudio-daemon or pipewire
```

The LuCI page reports the same thing, and separately warns when no card is
detected in `/proc/asound/cards`.

Manual checks, in order:

```bash
# Is a card attached?
cat /proc/asound/cards

# Is the sound server up?
ps | grep -E 'pulseaudio|pipewire'
ls -l /var/run/pulse/native

# Does the sound server see an output?
pactl list short sinks        # needs pulseaudio-tools

# Can anything actually make noise?
speaker-test -t sine -f 440 -l 1
```

## Two permissions, two groups

Getting an unprivileged client talking to a system-mode PulseAudio needs **both**
of these, and they are different groups. This is the part that is easy to get
wrong, and both were verified in PulseAudio's source:

**1. The `audio` group — client authorization.**

OpenWrt builds PulseAudio with:

```
-Daccess_group=audio
```

and `module-native-protocol-unix` falls back to that group for authorization in
system mode (`protocol-native.c`):

```c
o->auth_group = enabled ? pa_xstrdup(pa_modargs_get_value(ma, "auth-group",
                    pa_in_system_mode() ? PA_ACCESS_GROUP : NULL)) : NULL;
```

A connecting client is accepted if its uid matches, or if its gid *is* the access
group, or if it is a member of it (`pa_uid_in_group`). So on OpenWrt the group
that gets a client past authentication is **`audio`**, not `pulse`.

That matters because `base-files` ships no `audio` group at all, and
`pulseaudio-daemon` does not create one either — it only declares `pulse=51`.
This package's `USERID` line is therefore what brings the group into existence:

```
USERID:=soloist=soloist:audio=29,pulse
```

**2. The `pulse` group — reaching the socket.**

OpenWrt's PulseAudio init creates the runtime directory with:

```sh
mkdir -m 0755 -p /var/run/pulse
chmod 0750 /var/run/pulse
chown pulse:pulse /var/run/pulse
```

`0750 pulse:pulse` means a client that is not `pulse` and not in the `pulse`
group cannot traverse into the directory, so it never reaches `/var/run/pulse/native`
regardless of authorization. Hence the second group.

**3. The cookie.**

System-mode PulseAudio also writes a shared cookie, and a client normally
presents it. It is owned by the `pulse` user with restrictive permissions, which
an unprivileged client cannot read, so the init script widens it to `0640` with
group `audio` before starting the daemon:

```sh
chgrp audio "$cookie"
chmod 0640 "$cookie"
```

**In practice**, authentication succeeds on the group check alone before the
cookie is ever compared, so the cookie step is belt-and-braces. It is kept
because it costs nothing and covers the case where `auth-group` has been turned
off in `system.pa`.

If none of this works, set **Run as root** in LuCI: the daemon then matches
PulseAudio's own uid check (`creds->uid == getuid()`) and every group question
disappears. That is a diagnostic, not a deployment.

## Privileges, summarized

| Group | Why | Exists by default? |
|---|---|---|
| `audio` (gid 29) | PulseAudio client authorization (`access_group=audio`) | **No** — created by this package's `USERID` |
| `pulse` | traverse `/var/run/pulse` (mode `0750 pulse:pulse`) | Yes — created by `pulseaudio-daemon` |

`procd_set_param user` calls `initgroups()` against `/etc/group`, so both
supplementary memberships apply to the daemon.

## Summary of what is configurable

Audio output routing **is** configurable, and Spotify's own flag for it is:

| Setting | Mechanism | Notes |
|---|---|---|
| Output on PipeWire | `-d`, `--pipewire-device DEVICE` | Official Soloist flag. A PipeWire node name or ID. |
| Output on PulseAudio | `PULSE_SINK=<sink>` | No Soloist flag exists for PulseAudio. `PULSE_SINK` is PulseAudio's own standard client setting, honoured by libpulse. |
| Startup volume | `-i`, `--initial-volume N` | 0–100. |

Everything else about output — which card, which jack, HDMI vs analog — resolves
through whichever of the first two applies.

## Things that genuinely will not work

- **Bitrate or quality selection.** There is no `--bitrate` flag. Nothing in
  `soloist --help` corresponds to it, and the stream quality is negotiated with
  Spotify's servers.
- **Direct ALSA or JACK output.** No build links either library. Audio always
  goes through a sound server.
- **A Soloist flag for choosing a PulseAudio sink.** This one is a real gap:
  `--pipewire-device` is PipeWire-only, so on PulseAudio the selection has to go
  through `PULSE_SINK`. That is not a workaround invented here — it is how
  PulseAudio clients select a sink.
- **Volume normalisation.** Not a flag. It does not exist.
- **Running Soloist on a musl OpenWrt image.** Unrelated to audio, but it stops
  you before you get this far — see [limitations.md](limitations.md).

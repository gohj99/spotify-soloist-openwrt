#!/bin/sh
#
# spotify-soloist-selftest -- on-device checks for the installed package.
#
# Run this on the router itself (not from a workstation): every check reads
# device state, and a couple of them inspect hardware.
#
# It reports what it finds. It does not claim success for anything it could not
# actually observe, and a failing check is a finding, not a script error.

echo "=== Spotify Soloist self-test ==="
echo "host: $(uname -n)  arch: $(uname -m)  kernel: $(uname -r)"
echo

PASS=0
FAIL=0
WARN=0

ok()   { PASS=$((PASS + 1)); printf '  ok    %s\n' "$1"; }
bad()  { FAIL=$((FAIL + 1)); printf '  FAIL  %s\n' "$1"; }
warn() { WARN=$((WARN + 1)); printf '  warn  %s\n' "$1"; }

check_file() {
	[ -f "$1" ] && ok "$1 present" || bad "$1 missing"
}

check_exec() {
	[ -x "$1" ] && ok "$1 executable" || bad "$1 missing or not executable"
}

# ---------------------------------------------------------------------------
echo "--- packages"
# ---------------------------------------------------------------------------

if opkg list-installed 2>/dev/null | grep -q '^spotify-soloist '; then
	ok "spotify-soloist installed: $(opkg list-installed | grep '^spotify-soloist ' | cut -d' ' -f3)"
else
	bad "spotify-soloist is not installed"
fi

if opkg list-installed 2>/dev/null | grep -q '^luci-app-spotify-soloist '; then
	ok "luci-app-spotify-soloist installed"
else
	warn "luci-app-spotify-soloist is not installed (CLI still works)"
fi

for p in pulseaudio-daemon pulseaudio-tools libpulse curl ca-bundle \
         kmod-sound-core kmod-usb-audio; do
	opkg list-installed 2>/dev/null | grep -q "^$p " && ok "$p" || warn "$p missing"
done

# ---------------------------------------------------------------------------
echo
echo "--- files"
# ---------------------------------------------------------------------------

check_exec /usr/sbin/soloist
check_exec /usr/bin/spotify-soloist-updater
check_exec /usr/bin/spotify-soloist-check
check_exec /usr/bin/spotify-soloist-set-key
check_exec /usr/bin/spotify-soloist-status
check_exec /usr/bin/spotify-soloist-audio
check_file /usr/lib/spotify-soloist/common.sh
check_file /etc/init.d/spotify-soloist
check_file /etc/config/spotify-soloist

# ---------------------------------------------------------------------------
echo
echo "--- architecture and libc"
# ---------------------------------------------------------------------------

case "$(uname -m)" in
	aarch64|arm64|armv7l|armv6l|armv7|arm|x86_64|amd64)
		ok "$(uname -m) has a Spotify build"
		;;
	*)
		bad "$(uname -m) has no Spotify build; the package should not have installed"
		;;
esac

if ls /lib/ld-linux-*.so.* >/dev/null 2>&1; then
	ok "glibc loader present"
else
	bad "no glibc loader found; this is a musl system and the binary cannot run"
fi

if [ -x /usr/sbin/soloist ]; then
	out=$(/usr/sbin/soloist --version 2>&1)
	rc=$?
	if [ $rc -eq 0 ]; then
		ok "soloist runs: $out"
	else
		bad "soloist exists but will not run (rc=$rc): $out"
	fi
fi

# ---------------------------------------------------------------------------
echo
echo "--- build expiry"
# ---------------------------------------------------------------------------

if [ -x /usr/sbin/soloist ]; then
	days=$(/usr/bin/spotify-soloist-check --days 2>/dev/null | tail -n 1)
	case "$days" in
		''|*[!0-9-]*)
			warn "could not determine remaining days"
			;;
		*)
			if [ "$days" -le 0 ]; then
				bad "build expired $((0 - days)) day(s) ago; run the updater"
			elif [ "$days" -le 15 ]; then
				warn "$days day(s) left; the updater should be running"
			else
				ok "$days day(s) left"
			fi
			;;
	esac
fi

if crontab -l 2>/dev/null | grep -q 'spotify-soloist-check'; then
	ok "update check scheduled: $(crontab -l | grep spotify-soloist-check | head -n 1)"
else
	warn "no cron entry for spotify-soloist-check"
fi

# ---------------------------------------------------------------------------
echo
echo "--- API key"
# ---------------------------------------------------------------------------

if [ -s /etc/spotify-soloist/api-key ]; then
	perms=$(ls -l /etc/spotify-soloist/api-key 2>/dev/null | cut -d' ' -f1)
	ok "API key stored ($perms)"
	case "$perms" in
		-rw-------*) ;;
		*)
			warn "key permissions are not 0600"
			;;
	esac
else
	bad "no API key stored; the service cannot log in"
fi

# ---------------------------------------------------------------------------
echo
echo "--- sound hardware and server"
# ---------------------------------------------------------------------------

if [ -r /proc/asound/cards ] && grep -q '^\s*[0-9]' /proc/asound/cards 2>/dev/null; then
	ok "sound card(s) present:"
	sed -n 's/^/        /p' /proc/asound/cards | head -n 8
else
	bad "no sound card in /proc/asound/cards (missing kernel module?)"
fi

if pidof pulseaudio >/dev/null 2>&1 || pidof pipewire >/dev/null 2>&1; then
	ok "sound server is running"
else
	bad "no sound server running; install pulseaudio-daemon or pipewire"
fi

if [ -S /var/run/pulse/native ]; then
	ok "pulseaudio socket present"
else
	warn "no /var/run/pulse/native socket"
fi

# The group checks below are the ones that actually decide whether an
# unprivileged client can talk to PulseAudio, and they are easy to get wrong.
# See docs/audio-output.md.
if grep -q '^audio:' /etc/group; then
	ok "audio group exists: $(grep '^audio:' /etc/group)"
else
	bad "no audio group -- PulseAudio is built with access_group=audio, so no client can authenticate"
fi

if [ -n "$(id -Gn soloist 2>/dev/null)" ]; then
	groups_of_soloist=$(id -Gn soloist 2>/dev/null)
	case " $groups_of_soloist " in
		*" audio "*) ok "soloist is in the audio group (PulseAudio authorization)" ;;
		*) bad "soloist is NOT in the audio group; PulseAudio will refuse it. groups: $groups_of_soloist" ;;
	esac
	case " $groups_of_soloist " in
		*" pulse "*) ok "soloist is in the pulse group (can traverse /var/run/pulse)" ;;
		*) warn "soloist is NOT in the pulse group; /var/run/pulse is 0750 pulse:pulse. groups: $groups_of_soloist" ;;
	esac
else
	warn "the soloist user does not exist; the daemon will run as root"
fi

# Does the daemon's runtime directory actually let it in?
if [ -d /var/run/pulse ]; then
	perm=$(ls -ld /var/run/pulse 2>/dev/null | awk '{print $1, $3":"$4}')
	echo "        /var/run/pulse: $perm"
fi

if [ -x /usr/bin/pactl ]; then
	sinks=$(/usr/bin/pactl list short sinks 2>/dev/null | wc -l)
	[ "$sinks" -gt 0 ] && ok "$sinks sink(s) available" || warn "no sinks listed"
fi

# ---------------------------------------------------------------------------
echo
echo "--- configuration"
# ---------------------------------------------------------------------------

enabled=$(uci -q get spotify-soloist.main.enabled)
[ "$enabled" = "1" ] && ok "service enabled in config" || warn "service disabled in config"

backend=$(uci -q get spotify-soloist.main.audio_backend)
out=$(uci -q get spotify-soloist.main.alsa_output)
echo "        backend=$backend alsa_output=${out:-auto}"

data_dir=$(uci -q get spotify-soloist.main.data_dir)
data_dir=${data_dir:-/etc/spotify-soloist/data}
if [ -d "$data_dir" ]; then
	ok "data directory exists: $data_dir"
	if [ -f "$data_dir/.device_id" ]; then
		ok "device identity present (paired)"
	else
		warn "no .device_id yet; not paired"
	fi
else
	warn "data directory $data_dir does not exist yet"
fi

cache_dir=$(uci -q get spotify-soloist.main.cache_dir)
cache_dir=${cache_dir:-/tmp/spotify-soloist/cache}
case "$cache_dir" in
	/tmp/*|/var/run/*)
		ok "cache is on volatile storage: $cache_dir"
		;;
	*)
		warn "cache is on persistent storage: $cache_dir"
		;;
esac

# ---------------------------------------------------------------------------
echo
echo "--- service state"
# ---------------------------------------------------------------------------

used=$(df / 2>/dev/null | awk 'NR==2 {print $5}' | tr -d '%')
if [ -n "$used" ] && [ "$used" -ge 95 ] 2>/dev/null; then
	warn "root filesystem is ${used}% full"
fi

if /etc/init.d/spotify-soloist running >/dev/null 2>&1; then
	ok "service is running (pid $(pgrep -f /usr/sbin/soloist | head -n 1))"
	/etc/init.d/spotify-soloist info 2>/dev/null | sed 's/^/        /'
else
	warn "service is not running"
	if [ "$enabled" = "1" ]; then
		echo "        it is enabled, so this is a failure; last log lines:"
		logread 2>/dev/null | grep -i soloist | tail -n 5 | sed 's/^/          /'
	fi
fi

# ---------------------------------------------------------------------------
echo
echo "--- LuCI"
# ---------------------------------------------------------------------------

if [ -f /usr/lib/lua/luci/controller/spotify-soloist.lua ]; then
	ok "LuCI controller installed"
else
	warn "LuCI controller not found"
fi

if [ -f /usr/lib/lua/luci/model/cbi/spotify-soloist.lua ]; then
	ok "LuCI model installed"
else
	warn "LuCI model not found"
fi

if [ -f /usr/share/rpcd/acl.d/luci-app-spotify-soloist.json ]; then
	ok "rpcd ACL installed"
fi

# ---------------------------------------------------------------------------
echo
echo "--- status script"
# ---------------------------------------------------------------------------

if status=$(/usr/bin/spotify-soloist-status 2>&1); then
	case "$status" in
		\{*\})
			ok "status script produced JSON"
			;;
		*)
			bad "status script output is not JSON: $status"
			;;
	esac
else
	bad "status script failed: $status"
fi

# ---------------------------------------------------------------------------
echo
echo "=== summary: $PASS ok, $WARN warning(s), $FAIL failure(s) ==="
[ "$FAIL" -eq 0 ] || exit 1
exit 0

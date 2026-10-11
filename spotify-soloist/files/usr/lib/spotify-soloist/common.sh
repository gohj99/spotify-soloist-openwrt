#!/bin/sh
# Shared helpers for the spotify-soloist package.
#
# Sourced by /usr/bin/spotify-soloist-updater and /usr/bin/spotify-soloist-check.
# Not executable on its own.
#
# Everything in here is derived from Spotify's official Soloist documentation and
# from inspecting the published binaries; see docs/soloist-reference.md.

# config_load()/config_get() live here. Only /etc/rc.common sources this
# automatically, so a plain script under /usr/bin that cron runs would otherwise
# fail with "config_load: not found".
[ -f /lib/functions.sh ] && . /lib/functions.sh

SOLOIST_BIN="/usr/sbin/soloist"

SOLOIST_CONF_DIR="/etc/spotify-soloist"
SOLOIST_API_KEY_FILE="${SOLOIST_CONF_DIR}/api-key"
SOLOIST_SHA256_FILE="${SOLOIST_CONF_DIR}/sha256"

# Persistent state: device identity, paired session, crash reports. Lives on
# flash because losing it forces a re-pair with the Spotify app.
SOLOIST_DATA_DIR="/etc/spotify-soloist/data"

# Volatile playback cache. Deliberately on tmpfs: OpenWrt routers have far less
# free flash than RAM, and the cache is rebuildable.
SOLOIST_CACHE_DIR="/tmp/spotify-soloist/cache"

SOLOIST_WORK_DIR="/tmp/spotify-soloist"
SOLOIST_LOG="${SOLOIST_WORK_DIR}/update.log"
SOLOIST_META="${SOLOIST_WORK_DIR}/build.txt"
SOLOIST_LOCK="/var/lock/spotify-soloist-update.lock"

SOLOIST_BUILD_BASE="https://soloist-builds.spotifycdn.com"
SOLOIST_BUILD_TTL_DAYS=90

log_msg() {
	logger -t "spotify-soloist" -p "${2:-user.info}" "$1"
	[ -n "${SOLOIST_QUIET:-}" ] || echo "$1"
}

# Map `uname -m` onto Spotify's archive names.
# Spotify publishes exactly three Linux builds, all glibc-only:
#   arm64 / arm32 / x86_64
soloist_archive_name() {
	case "$(uname -m)" in
		aarch64|arm64)
			echo "arm64"
			;;
		armv7l|armv6l|armv7|arm)
			echo "arm32"
			;;
		x86_64|amd64)
			echo "x86_64"
			;;
		*)
			return 1
			;;
	esac
}

soloist_archive_url() {
	local name
	name=$(soloist_archive_name) || return 1
	echo "${SOLOIST_BUILD_BASE}/soloist_release_${name}.tar.gz"
}

soloist_install_ready() {
	[ -x "${SOLOIST_BIN}" ]
}

soloist_prepare_dirs() {
	mkdir -p "${SOLOIST_DATA_DIR}" "${SOLOIST_CACHE_DIR}" "${SOLOIST_WORK_DIR}"
}

# Read the build epoch from `soloist --version`.
#
# Observed output on 1.3.9.9:
#   soloist 1.3.9.9 build 1791676872 (20261011) (g440165f200) (linux/x86_64)
#
# The bare integer after "build" is a Unix timestamp. The parenthesised
# YYYYMMDD is used as a fallback for older builds that only carry a date.
soloist_build_epoch() {
	[ -x "${SOLOIST_BIN}" ] || return 1

	local out= epoch= ymd=
	out=$("${SOLOIST_BIN}" --version 2>/dev/null) || return 1

	epoch=$(echo "$out" | sed -n 's/.* build \([0-9][0-9]*\) .*/\1/p')
	if [ -n "$epoch" ] && [ "$epoch" -gt 1000000000 ] 2>/dev/null; then
		echo "$epoch"
		return 0
	fi

	ymd=$(echo "$out" | sed -n 's/.*(\([0-9]\{8\}\)).*/\1/p')
	if [ -n "$ymd" ]; then
		# Convert YYYYMMDD to a day number without needing date(1) parsing.
		local y=${ymd%????} m=${ymd#????} d=
		d=${m#??}
		m=${m%??}
		echo $(( $(days_from_civil "$y" "$m" "$d") * 86400 ))
		return 0
	fi

	return 1
}

# Days since 1970-01-01 for a civil date (Howard Hinnant's algorithm).
# Pure shell arithmetic so we never depend on date -d / date -r support.
days_from_civil() {
	local y=$1 m=$2 d=$3
	local era yoe doy doe mm

	# A date in January or February belongs to the previous year for the
	# purposes of this algorithm.
	if [ "$m" -le 2 ]; then
		y=$(( y - 1 ))
	fi

	if [ "$y" -ge 0 ]; then
		era=$(( y / 400 ))
	else
		era=$(( (y - 399) / 400 ))
	fi
	yoe=$(( y - era * 400 ))

	if [ "$m" -gt 2 ]; then
		mm=$(( m - 3 ))
	else
		mm=$(( m + 9 ))
	fi
	doy=$(( (153 * mm + 2) / 5 + d - 1 ))
	doe=$(( yoe * 365 + yoe / 4 - yoe / 100 + doy ))

	echo $(( era * 146097 + doe - 719468 ))
}

# Remaining days before the build expires. Prints -1 when unknown.
soloist_days_remaining() {
	local build now

	build=$(soloist_build_epoch) || {
		echo "-1"
		return 1
	}

	now=$(date +%s 2>/dev/null) || {
		echo "-1"
		return 1
	}

	echo $(( (build + SOLOIST_BUILD_TTL_DAYS * 86400 - now) / 86400 ))
}

# Remaining days for an explicit build timestamp.
soloist_days_remaining_for_epoch() {
	local build="$1" now

	now=$(date +%s 2>/dev/null) || {
		echo "-1"
		return 1
	}

	echo $(( (build + SOLOIST_BUILD_TTL_DAYS * 86400 - now) / 86400 ))
}

# PID of the running daemon, or an empty string.
#
# Reads the pid file the daemon writes rather than scanning the process table:
# `pkill` is not in OpenWrt's default busybox build, and matching on the command
# line risks catching something unrelated. `pgrep` is available by default, so it
# is used only as a cross-check that the pid is really alive.
soloist_running_pid() {
	local pidfile="${SOLOIST_DATA_DIR}/soloist.pid"
	local pid=""

	if [ -r "$pidfile" ]; then
		pid=$(cat "$pidfile" 2>/dev/null | tr -dc '0-9')
	fi

	if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
		echo "$pid"
		return 0
	fi

	# The pid file is missing or stale. Try the procd instance instead.
	if command -v pgrep >/dev/null 2>&1; then
		pid=$(pgrep -f "${SOLOIST_BIN}" 2>/dev/null | head -n 1)
		if [ -n "$pid" ]; then
			echo "$pid"
			return 0
		fi
	fi

	return 1
}

# Human-readable version + expiry, cached in /tmp for LuCI to read cheaply.
soloist_write_meta() {
	[ -x "${SOLOIST_BIN}" ] || return 1

	local version build expiry days
	version=$("${SOLOIST_BIN}" --version 2>/dev/null)
	build=$(soloist_build_epoch 2>/dev/null)
	days=$(soloist_days_remaining 2>/dev/null)

	if [ -n "$build" ]; then
		expiry=$(( build + SOLOIST_BUILD_TTL_DAYS * 86400 ))
	else
		expiry=0
	fi

	mkdir -p "${SOLOIST_WORK_DIR}"
	{
		echo "version=${version}"
		echo "build_epoch=${build:-0}"
		echo "expires_epoch=${expiry}"
		echo "days_remaining=${days:--1}"
		echo "checked_epoch=$(date +%s)"
	} > "${SOLOIST_META}"
}

# Read one key from the meta cache written by soloist_write_meta().
soloist_meta_get() {
	sed -n "s/^$1=//p" "${SOLOIST_META}" 2>/dev/null | head -n 1
}

# Only the hash of the API key is echoed; the key itself is never logged.
soloist_api_key_present() {
	[ -s "${SOLOIST_API_KEY_FILE}" ] &&
		[ -n "$(sed -n '/[^[:space:]]/p' "${SOLOIST_API_KEY_FILE}" | head -n 1)" ]
}

soloist_take_lock() {
	command -v flock >/dev/null 2>&1 || return 0
	mkdir -p "$(dirname "${SOLOIST_LOCK}")"
	exec 9>"${SOLOIST_LOCK}"
	flock -n 9 || return 1
	return 0
}

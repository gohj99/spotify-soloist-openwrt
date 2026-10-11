# Build Artifacts

This directory is for **CI-produced IPK files** that demonstrate the package builds successfully on the standard OpenWrt SDK.

## What's here

When you push to GitHub, the Actions workflow in `.github/workflows/build.yml` compiles both packages:

- `spotify-soloist_*.ipk` — the daemon, helpers, init script, and default config
- `luci-app-spotify-soloist_*.ipk` — the LuCI web interface

The workflow runs on **x86_64 with musl libc**, using `CONFIG_BROKEN=y` to bypass the `@(!USE_MUSL||BROKEN)` gate that normally hides glibc-only packages on musl systems. This is the standard OpenWrt escape hatch for CI.

## Installation

These IPKs are **architecture-independent** (`PKGARCH:=all`) and can be installed on any OpenWrt 24.10+ system:

```bash
opkg install spotify-soloist_*.ipk luci-app-spotify-soloist_*.ipk
```

After installation:

1. Generate an API key at https://developer.spotify.com/dashboard/soloist
2. Configure via LuCI: **Services → Spotify Soloist**
3. The Soloist binary downloads on first start; check with:
   ```bash
   /etc/init.d/spotify-soloist info
   ```

## Why `CONFIG_BROKEN=y`?

The Soloist binary is **x86_64 glibc** only. The package's `DEPENDS:=@(!USE_MUSL||BROKEN)` hides it on musl systems to prevent installation failures. `CONFIG_BROKEN=y` in CI overrides that gate so the *package structure* can be verified — the IPK builds, installs, and the updater downloads the correct binary at runtime.

Users on musl systems won't see the package in their `opkg` feed unless they set `CONFIG_BROKEN=y` in their own builds. That's intentional: the binary won't work there, and the package should stay hidden.

## Contents verification

Each IPK contains:

### spotify-soloist

- `/usr/bin/spotify-soloist-updater` — downloads and verifies the Soloist binary
- `/usr/bin/spotify-soloist-check` — cron job that keeps the build up to date
- `/usr/bin/spotify-soloist-cron` — syncs the crontab with the UCI schedule
- `/usr/bin/spotify-soloist-status` — JSON status for LuCI
- `/usr/bin/spotify-soloist-audio` — audio routing helper
- `/usr/bin/spotify-soloist-set-key` — stores the API key securely
- `/usr/lib/spotify-soloist/common.sh` — shared shell functions
- `/etc/init.d/spotify-soloist` — procd init script
- `/etc/config/spotify-soloist` — UCI defaults
- `/etc/spotify-soloist/sha256` — binary verification hashes

### luci-app-spotify-soloist

- LuCI controller and CBI model
- Status page with live endpoint/expiry/audio routing
- Custom widgets for the masked API key field

Both are MIT-licensed.

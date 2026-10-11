# Spotify Soloist for OpenWrt

Complete Spotify Connect integration for OpenWrt routers.

[中文文档](README.md) | **English**

## Introduction

This project provides full Spotify Soloist integration for OpenWrt, including:

- **spotify-soloist**: Core service package with binary management and auto-update mechanism
- **luci-app-spotify-soloist**: Web management interface

### Key Features

✅ **Auto-Update Mechanism** - Solves Spotify's 90-day expiration limitation  
✅ **LuCI Web Interface** - Visual configuration and status monitoring  
✅ **Multi-Architecture Support** - ARMv7, ARMv8/AArch64, x86_64  
✅ **WebSocket API** - Local integration interface  
✅ **UCI Configuration** - Standard OpenWrt configuration management  
✅ **Procd Integration** - Auto-restart and process monitoring  

## Requirements

- OpenWrt 21.02 or newer
- Supported architectures: ARMv7, ARMv8/AArch64, x86_64
- At least 50MB free storage
- Internet connection (for binary downloads and updates)
- PulseAudio or PipeWire audio system

## Quick Start

### Installation

```bash
# Copy packages to router
scp spotify-soloist_*.ipk luci-app-spotify-soloist_*.ipk root@192.168.1.1:/tmp/

# SSH to router
ssh root@192.168.1.1

# Install
opkg install /tmp/spotify-soloist_*.ipk
opkg install /tmp/luci-app-spotify-soloist_*.ipk
```

### Configuration

**Via LuCI Web Interface:**

1. Navigate to: Services → Spotify Soloist
2. Enable the service
3. Set device name
4. Save & Apply

**Via Command Line:**

```bash
uci set spotify-soloist.main.enabled='1'
uci set spotify-soloist.main.device_name='OpenWrt Speaker'
uci commit spotify-soloist
/etc/init.d/spotify-soloist enable
/etc/init.d/spotify-soloist start
```

### Usage

1. Open Spotify app on your phone/computer
2. Play any song
3. Tap the **Devices** button
4. Select your OpenWrt device
5. 🎵 Enjoy your music!

## Documentation

- [Quick Start Guide](QUICKSTART.md)
- [Architecture Design](docs/architecture.md)
- [Development Guide](DEVELOPMENT.md)
- [Contributing Guide](CONTRIBUTING.md)
- [Changelog](CHANGELOG.md)

## Configuration Options

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `enabled` | Boolean | `0` | Enable service |
| `device_name` | String | `OpenWrt Spotify` | Device name in Spotify Connect |
| `ws_enabled` | Boolean | `1` | Enable WebSocket API |
| `ws_port` | Integer | `8080` | WebSocket port |
| `auto_update` | Boolean | `1` | Enable auto-update |
| `update_threshold` | Integer | `15` | Update threshold (days) |
| `bitrate` | String | `default` | Audio bitrate |
| `cache_size_limit` | Integer | `512` | Cache size limit (MB) |

## Auto-Update Mechanism

Spotify Soloist binaries expire after 90 days. This project solves it through:

1. **Scheduled Checks** (Cron) - Weekly by default
2. **Threshold Trigger** - Auto-update when remaining days ≤ threshold
3. **Manual Update** - Web interface and CLI support

## Troubleshooting

### Device not visible in Spotify

```bash
# Check service status
/etc/init.d/spotify-soloist status

# View logs
logread | grep soloist
```

### Service fails to start

```bash
# Download binary manually
/usr/bin/spotify-soloist-updater

# Restart service
/etc/init.d/spotify-soloist restart
```

### Check remaining days

```bash
# Command line
/usr/bin/spotify-soloist-check --days

# Or check in LuCI interface
```

## Building from Source

```bash
# Download OpenWrt SDK
wget https://downloads.openwrt.org/releases/23.05.0/targets/<target>/<subtarget>/openwrt-sdk-*.tar.xz
tar xf openwrt-sdk-*.tar.xz
cd openwrt-sdk-*

# Clone this repository
git clone https://github.com/yourusername/spotify-soloist-openwrt.git package/spotify-soloist-openwrt

# Build
make package/spotify-soloist-openwrt/spotify-soloist/compile V=s
make package/spotify-soloist-openwrt/luci-app-spotify-soloist/compile V=s
```

## Contributing

Contributions are welcome! Please read [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

## License

- **spotify-soloist**: Proprietary (Spotify)
- **luci-app-spotify-soloist**: MIT License

## Acknowledgments

- [Spotify](https://www.spotify.com/) - For providing Soloist client
- [OpenWrt Project](https://openwrt.org/)
- [LuCI](https://github.com/openwrt/luci)

## Links

- [Spotify Soloist Documentation](https://developer.spotify.com/documentation/soloist)
- [OpenWrt Developer Guide](https://openwrt.org/docs/guide-developer/start)
- [LuCI Development](https://github.com/openwrt/luci/wiki)

## FAQ

**Q: Does it support Spotify Free accounts?**  
A: Yes, both Free and Premium accounts are supported.

**Q: Can I use it on multiple OpenWrt devices?**  
A: Yes, each device appears as a separate Spotify Connect device.

**Q: What about audio latency?**  
A: Latency depends on network and device performance, typically 1-2 seconds.

**Q: Does it support lossless audio?**  
A: Maximum supported bitrate is 320kbps (Ogg Vorbis).

---

**Note**: Using Spotify Soloist requires compliance with Spotify's Terms of Service.

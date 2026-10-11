# Spotify Soloist for OpenWrt

将 Spotify Connect 带到 OpenWrt 路由器的完整解决方案。

## 项目介绍

这个项目为 OpenWrt 提供了 Spotify Soloist 的完整集成，包括：

- **spotify-soloist**: 核心服务包，包含二进制文件管理和自动更新机制
- **luci-app-spotify-soloist**: Web 管理界面

### 主要特性

✅ **自动更新机制** - 解决 Spotify 90天过期限制  
✅ **LuCI Web 界面** - 可视化配置和状态监控  
✅ **多架构支持** - ARMv7, ARMv8/AArch64, x86_64  
✅ **WebSocket API** - 本地集成接口  
✅ **UCI 配置系统** - 标准 OpenWrt 配置管理  
✅ **Procd 服务集成** - 自动重启和进程监控  

## 系统要求

- OpenWrt 21.02 或更新版本
- 支持的架构：ARMv7, ARMv8/AArch64, x86_64
- 至少 50MB 可用存储空间
- 互联网连接（用于下载二进制文件和更新）
- PulseAudio 或 PipeWire 音频系统

## 安装

### 方法一：通过 OpenWrt SDK 编译

1. **准备 OpenWrt SDK**

```bash
# 下载对应架构的 SDK
wget https://downloads.openwrt.org/releases/23.05.0/targets/<target>/<subtarget>/openwrt-sdk-*.tar.xz
tar xf openwrt-sdk-*.tar.xz
cd openwrt-sdk-*
```

2. **添加包到 SDK**

```bash
# 克隆本仓库到 package 目录
git clone https://github.com/yourusername/spotify-soloist-openwrt.git package/spotify-soloist-openwrt

# 或手动复制
mkdir -p package/spotify-soloist-openwrt
cp -r /path/to/this/repo/* package/spotify-soloist-openwrt/
```

3. **编译包**

```bash
# 更新 feeds
./scripts/feeds update -a
./scripts/feeds install -a

# 配置要编译的包
make menuconfig
# 在 Multimedia -> spotify-soloist 选择 <M>
# 在 LuCI -> Applications -> luci-app-spotify-soloist 选择 <M>

# 编译
make package/spotify-soloist-openwrt/spotify-soloist/compile V=s
make package/spotify-soloist-openwrt/luci-app-spotify-soloist/compile V=s
```

4. **安装到路由器**

```bash
# 生成的 ipk 文件位于 bin/packages/<arch>/base/
scp bin/packages/*/base/spotify-soloist*.ipk root@192.168.1.1:/tmp/
scp bin/packages/*/luci/luci-app-spotify-soloist*.ipk root@192.168.1.1:/tmp/

# SSH 到路由器
ssh root@192.168.1.1

# 安装
opkg install /tmp/spotify-soloist*.ipk
opkg install /tmp/luci-app-spotify-soloist*.ipk
```

### 方法二：直接安装预编译包

如果提供了预编译的 ipk 包：

```bash
# 下载 ipk 包
wget https://your-server/spotify-soloist_1.0.0-1_<arch>.ipk
wget https://your-server/luci-app-spotify-soloist_1.0.0-1_all.ipk

# 传输到路由器
scp *.ipk root@192.168.1.1:/tmp/

# 安装
ssh root@192.168.1.1
opkg install /tmp/spotify-soloist_*.ipk
opkg install /tmp/luci-app-spotify-soloist_*.ipk
```

## 配置

### 通过 LuCI Web 界面

1. 登录 LuCI 管理界面
2. 导航到 **服务 → Spotify Soloist**
3. 配置设置：
   - ✅ 启用服务
   - 设置设备名称（会显示在 Spotify Connect 列表中）
   - 配置音频质量
   - 启用 WebSocket API（如需要）
   - 配置自动更新设置
4. 点击 **保存并应用**

### 通过命令行（UCI）

```bash
# 启用服务
uci set spotify-soloist.main.enabled='1'

# 设置设备名称
uci set spotify-soloist.main.device_name='OpenWrt Living Room'

# 配置音频质量
uci set spotify-soloist.main.bitrate='320'

# 启用 WebSocket API
uci set spotify-soloist.main.ws_enabled='1'
uci set spotify-soloist.main.ws_port='8080'

# 配置自动更新
uci set spotify-soloist.main.auto_update='1'
uci set spotify-soloist.main.update_threshold='15'

# 提交更改
uci commit spotify-soloist

# 启动服务
/etc/init.d/spotify-soloist enable
/etc/init.d/spotify-soloist start
```

## 使用

### 基本操作

```bash
# 启动服务
/etc/init.d/spotify-soloist start

# 停止服务
/etc/init.d/spotify-soloist stop

# 重启服务
/etc/init.d/spotify-soloist restart

# 查看状态
/etc/init.d/spotify-soloist status

# 查看日志
logread | grep soloist
```

### 手动更新二进制文件

```bash
# 检查剩余天数
/usr/bin/spotify-soloist-check --days

# 强制更新
/usr/bin/spotify-soloist-check --force

# 或直接运行更新脚本
/usr/bin/spotify-soloist-updater
```

### 在 Spotify 中使用

1. 启动 OpenWrt 上的 Spotify Soloist 服务
2. 在手机、电脑或平板上打开 Spotify 应用
3. 开始播放任意歌曲
4. 点击播放界面的 **设备** 按钮（通常是扬声器或电视图标）
5. 在可用设备列表中找到你的 OpenWrt 设备（显示你配置的设备名称）
6. 选择该设备，音频将从 OpenWrt 设备播放

## 自动更新机制

Spotify Soloist 二进制文件有 90 天有效期。本项目通过以下机制解决：

### 1. 定期检查（Cron）
- 默认每周日凌晨 3 点检查一次
- 可通过 `check_update_cron` 配置自定义

### 2. 阈值触发
- 当剩余天数 ≤ 阈值（默认 15 天）时自动更新
- 可通过 `update_threshold` 配置

### 3. Web 界面手动更新
- LuCI 界面显示剩余天数
- 提供 **Update Now** 按钮立即更新

### 4. 命令行手动更新
```bash
/usr/bin/spotify-soloist-check --force
```

## 文件结构

### spotify-soloist 包

```
spotify-soloist/
├── Makefile                                 # OpenWrt 包构建文件
└── files/
    ├── etc/
    │   ├── config/spotify-soloist          # UCI 配置文件
    │   └── init.d/spotify-soloist          # Procd init 脚本
    └── usr/
        └── bin/
            ├── spotify-soloist-updater      # 二进制更新脚本
            └── spotify-soloist-check        # 过期检查脚本
```

### luci-app-spotify-soloist 包

```
luci-app-spotify-soloist/
├── Makefile                                 # LuCI 包构建文件
├── luasrc/
│   ├── controller/
│   │   └── spotify-soloist.lua             # 页面路由控制器
│   ├── model/
│   │   └── cbi/
│   │       └── spotify-soloist.lua         # 配置界面模型
│   └── view/
│       └── spotify-soloist/
│           └── status.htm                   # 状态显示模板
└── root/
    └── usr/
        └── share/
            └── rpcd/
                └── acl.d/
                    └── luci-app-spotify-soloist.json  # 权限配置
```

## 配置选项

| 选项 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| `enabled` | Boolean | `0` | 启用服务 |
| `device_name` | String | `OpenWrt Spotify` | Spotify Connect 设备名称 |
| `ws_enabled` | Boolean | `1` | 启用 WebSocket API |
| `ws_port` | Integer | `8080` | WebSocket 端口 |
| `auto_update` | Boolean | `1` | 启用自动更新 |
| `update_threshold` | Integer | `15` | 更新阈值（天） |
| `check_update_cron` | String | `0 3 * * 0` | Cron 表达式 |
| `cache_size_limit` | Integer | `512` | 缓存大小限制（MB） |
| `bitrate` | String | `default` | 音频比特率 |
| `normalize_volume` | Boolean | `0` | 音量标准化 |
| `log_level` | String | `info` | 日志级别 |

## 故障排除

### 服务无法启动

```bash
# 检查二进制文件是否存在
ls -l /usr/sbin/soloist

# 如果不存在，手动下载
/usr/bin/spotify-soloist-updater

# 查看详细日志
logread -f | grep -i soloist
```

### 设备在 Spotify 中不可见

1. 确认服务正在运行：
   ```bash
   ps | grep soloist
   ```

2. 检查网络连接：
   - OpenWrt 设备和 Spotify 客户端需在同一局域网
   - 确认 mDNS/Avahi 服务正常

3. 查看日志中的错误信息：
   ```bash
   logread | grep -i soloist
   ```

### 音频没有输出

1. 检查音频系统：
   ```bash
   # 检查 PulseAudio
   pulseaudio --check
   
   # 或检查 PipeWire
   ps | grep pipewire
   ```

2. 测试音频输出：
   ```bash
   speaker-test -t sine -f 1000 -l 1
   ```

### 更新失败

```bash
# 查看更新日志
cat /tmp/soloist-update.log

# 检查网络连接
ping -c 3 developer.spotify.com

# 手动下载测试
curl -I https://developer.spotify.com/soloist/download/latest/linux-aarch64/soloist.tar.gz
```

### 90 天后服务停止

如果自动更新失败，手动更新：

```bash
/usr/bin/spotify-soloist-updater
/etc/init.d/spotify-soloist restart
```

## WebSocket API

启用 WebSocket API 后，可通过本地接口控制播放：

```javascript
// 连接到 WebSocket（仅限本地）
const ws = new WebSocket('ws://127.0.0.1:8080');

ws.onopen = () => {
    // 发送控制命令
    ws.send(JSON.stringify({
        type: 'play'
    }));
};

ws.onmessage = (event) => {
    // 接收播放状态
    const data = JSON.parse(event.data);
    console.log('Playback state:', data);
};
```

**安全提示**: WebSocket API 仅绑定到 127.0.0.1，不应暴露到外网。

## 性能优化

### 减少存储占用

```bash
# 减小缓存大小
uci set spotify-soloist.main.cache_size_limit='256'
uci commit spotify-soloist
/etc/init.d/spotify-soloist restart
```

### 降低带宽使用

```bash
# 使用较低比特率
uci set spotify-soloist.main.bitrate='160'
uci commit spotify-soloist
/etc/init.d/spotify-soloist restart
```

## 卸载

```bash
# 停止并禁用服务
/etc/init.d/spotify-soloist stop
/etc/init.d/spotify-soloist disable

# 删除 cron 任务
crontab -l | grep -v "spotify-soloist-check" | crontab -

# 卸载包
opkg remove luci-app-spotify-soloist
opkg remove spotify-soloist

# 删除配置（可选）
rm -f /etc/config/spotify-soloist
```

## 贡献

欢迎提交 Issue 和 Pull Request！

## 许可证

- **spotify-soloist**: 遵循 Spotify 的专有许可协议
- **luci-app-spotify-soloist**: Apache-2.0 License

## 致谢

- [Spotify](https://www.spotify.com/) - 提供 Soloist 客户端
- [OpenWrt 项目](https://openwrt.org/)
- [LuCI](https://github.com/openwrt/luci)

## 相关链接

- [Spotify Soloist 官方文档](https://developer.spotify.com/documentation/soloist)
- [OpenWrt 开发者指南](https://openwrt.org/docs/guide-developer/start)
- [LuCI 应用开发](https://github.com/openwrt/luci/wiki)

## 常见问题

### Q: 支持 Spotify Free 账户吗？
A: 是的，Spotify Soloist 同时支持 Free 和 Premium 账户。

### Q: 可以在多个 OpenWrt 设备上使用吗？
A: 可以，每个设备会显示为独立的 Spotify Connect 设备。

### Q: 音频延迟如何？
A: 延迟取决于网络状况和设备性能，通常在 1-2 秒左右。

### Q: 支持高品质无损音频吗？
A: Soloist 支持的最高比特率是 320kbps（Ogg Vorbis）。

### Q: 如何更改设备在 Spotify 中显示的图标？
A: 目前 Soloist 不支持自定义设备图标。

---

**注意**: 使用 Spotify Soloist 需要遵守 Spotify 的服务条款。

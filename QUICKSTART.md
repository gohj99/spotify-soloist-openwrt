# Spotify Soloist OpenWrt - 快速开始

## 5 分钟快速上手

### 1. 下载安装包

访问 [Releases](https://github.com/yourusername/spotify-soloist-openwrt/releases) 下载对应架构的 ipk 包。

### 2. 安装到路由器

```bash
# 传输到路由器
scp spotify-soloist_*.ipk luci-app-spotify-soloist_*.ipk root@192.168.1.1:/tmp/

# SSH 登录
ssh root@192.168.1.1

# 安装
opkg install /tmp/spotify-soloist_*.ipk
opkg install /tmp/luci-app-spotify-soloist_*.ipk
```

### 3. 启用服务

**方法 A: 通过 LuCI Web 界面**

1. 浏览器访问: `http://192.168.1.1`
2. 导航到: 服务 → Spotify Soloist
3. 勾选 **启用**
4. 设置 **设备名称** (例如: "Living Room Speaker")
5. 点击 **保存并应用**

**方法 B: 通过命令行**

```bash
# 启用并启动服务
uci set spotify-soloist.main.enabled='1'
uci set spotify-soloist.main.device_name='My OpenWrt Speaker'
uci commit spotify-soloist
/etc/init.d/spotify-soloist enable
/etc/init.d/spotify-soloist start
```

### 4. 在 Spotify 中使用

1. 打开 Spotify 应用（手机/电脑/平板）
2. 播放任意歌曲
3. 点击 **设备** 按钮（扬声器图标）
4. 选择你的 OpenWrt 设备
5. 🎵 开始享受音乐！

---

## 常见问题快速解答

### Q: 找不到设备？
```bash
# 检查服务状态
/etc/init.d/spotify-soloist status

# 查看日志
logread | grep soloist
```

### Q: 服务启动失败？
```bash
# 手动下载二进制文件
/usr/bin/spotify-soloist-updater

# 重启服务
/etc/init.d/spotify-soloist restart
```

### Q: 如何查看剩余天数？
```bash
# 命令行查看
/usr/bin/spotify-soloist-check --days

# 或访问 LuCI 界面查看
```

---

## 进阶配置

### 音频质量设置

```bash
# 320kbps 高品质
uci set spotify-soloist.main.bitrate='320'
uci commit spotify-soloist
/etc/init.d/spotify-soloist restart
```

### 启用 WebSocket API

```bash
uci set spotify-soloist.main.ws_enabled='1'
uci set spotify-soloist.main.ws_port='8080'
uci commit spotify-soloist
/etc/init.d/spotify-soloist restart
```

### 自定义自动更新

```bash
# 每天凌晨 2 点检查
uci set spotify-soloist.main.check_update_cron='0 2 * * *'
uci commit spotify-soloist

# 更新 cron 任务
crontab -l | grep -v spotify-soloist-check | crontab -
(crontab -l; echo "0 2 * * * /usr/bin/spotify-soloist-check") | crontab -
```

---

## 获取帮助

- 📖 [完整文档](README.md)
- 🐛 [报告问题](https://github.com/yourusername/spotify-soloist-openwrt/issues)
- 💬 [社区讨论](https://github.com/yourusername/spotify-soloist-openwrt/discussions)

---

**享受你的 Spotify 音乐！** 🎶

## v1.0.0 (2026-10-11)

### 🎉 首次发布

完整的 Spotify Soloist OpenWrt 集成方案。

#### ✨ 新功能

**核心包 (spotify-soloist)**
- 多架构支持：ARMv7, ARMv8/AArch64, x86_64
- 自动二进制下载和安装
- Procd 服务集成
- UCI 配置系统
- 90天过期自动更新机制
  - Cron 定期检查
  - 阈值触发更新
  - 手动更新接口
- 服务日志集成到 syslog

**LuCI Web 界面 (luci-app-spotify-soloist)**
- 实时状态监控
  - 服务运行状态
  - 剩余有效天数（带颜色警告）
  - 设备信息和版本
- 完整配置管理
  - 设备名称
  - 音频质量设置
  - WebSocket API 配置
  - 自动更新设置
- 操作功能
  - 刷新状态
  - 一键更新
  - 实时反馈

#### 📦 包含文件

**spotify-soloist/**
- Makefile
- files/etc/config/spotify-soloist
- files/etc/init.d/spotify-soloist
- files/usr/bin/spotify-soloist-updater
- files/usr/bin/spotify-soloist-check

**luci-app-spotify-soloist/**
- Makefile
- luasrc/controller/spotify-soloist.lua
- luasrc/model/cbi/spotify-soloist.lua
- luasrc/view/spotify-soloist/status.htm
- root/usr/share/rpcd/acl.d/luci-app-spotify-soloist.json

#### 📚 文档

- README.md - 完整的使用指南
- DEVELOPMENT.md - 开发者文档
- CONTRIBUTING.md - 贡献指南
- LICENSE - MIT 许可证
- CHANGELOG.md - 本文件

#### 🛠️ 工具脚本

- build.sh - 快速编译脚本
- test.sh - 测试套件

#### 🔧 配置选项

- `enabled` - 启用/禁用服务
- `device_name` - Spotify Connect 设备名称
- `ws_enabled` - WebSocket API 开关
- `ws_port` - WebSocket 端口
- `auto_update` - 自动更新开关
- `update_threshold` - 更新阈值（天）
- `check_update_cron` - Cron 检查计划
- `cache_size_limit` - 缓存大小限制
- `bitrate` - 音频比特率
- `normalize_volume` - 音量标准化
- `log_level` - 日志级别

#### 🎯 系统要求

- OpenWrt 21.02 或更新版本
- ARMv7 / ARMv8 / x86_64 架构
- 至少 50MB 可用空间
- PulseAudio 或 PipeWire
- 互联网连接

#### 🙏 致谢

- Spotify - 提供 Soloist 客户端
- OpenWrt 项目
- LuCI 项目
- 社区贡献者

---

## 未来计划

### v1.1.0 (计划中)

- [ ] 更精确的剩余天数检测
- [ ] 下载进度显示
- [ ] 离线包安装支持
- [ ] 多语言支持（英文、简体中文）
- [ ] 更好的错误处理和恢复

### v2.0.0 (远期)

- [ ] 播放状态集成（当前播放显示）
- [ ] 专辑封面显示
- [ ] 基本播放控制（通过 WebSocket API）
- [ ] 统计和历史记录
- [ ] 多实例支持
- [ ] 高级音频配置

---

**注意**: 版本遵循 [语义化版本](https://semver.org/) 规范。

# Spotify Soloist OpenWrt 项目开发日志

## 项目概述

为 OpenWrt 开发完整的 Spotify Soloist 集成方案，解决 90 天过期问题。

## 已完成的工作

### 1. 核心服务包 (spotify-soloist)

#### ✅ 文件结构
- `Makefile` - OpenWrt 包构建配置
- `files/etc/config/spotify-soloist` - UCI 配置文件
- `files/etc/init.d/spotify-soloist` - Procd init 服务脚本
- `files/usr/bin/spotify-soloist-updater` - 自动更新脚本
- `files/usr/bin/spotify-soloist-check` - 过期检查脚本

#### ✅ 核心功能
1. **多架构支持**: ARMv7, ARMv8/AArch64, x86_64
2. **自动二进制下载**: 首次安装时自动下载对应架构的二进制文件
3. **Procd 集成**: 完整的服务生命周期管理
4. **UCI 配置**: 标准 OpenWrt 配置系统
5. **自动更新机制**:
   - 定期检查（cron 任务）
   - 阈值触发（默认剩余 < 15 天）
   - 手动触发接口
   - 安全的原子替换（备份 → 下载 → 验证 → 安装）

#### ✅ 配置选项
- 设备名称
- WebSocket API 开关和端口
- 音频比特率
- 缓存大小
- 音量标准化
- 日志级别
- 自动更新设置

### 2. LuCI Web 界面 (luci-app-spotify-soloist)

#### ✅ 文件结构
- `Makefile` - LuCI 包构建配置
- `luasrc/controller/spotify-soloist.lua` - 路由控制器
- `luasrc/model/cbi/spotify-soloist.lua` - CBI 配置模型
- `luasrc/view/spotify-soloist/status.htm` - 状态显示模板
- `root/usr/share/rpcd/acl.d/luci-app-spotify-soloist.json` - 权限配置

#### ✅ 界面功能
1. **实时状态监控**:
   - 服务运行状态（运行中/已停止/已禁用）
   - 二进制文件状态
   - 剩余有效天数（带颜色警告）
   - 设备名称和版本信息
   - WebSocket API 状态

2. **配置管理**:
   - 基本设置（启用、设备名、比特率）
   - WebSocket API 配置
   - 自动更新设置
   - 高级选项（日志级别）

3. **操作按钮**:
   - 刷新状态
   - 立即更新
   - 实时反馈（带加载动画和结果提示）

4. **用户体验**:
   - 响应式设计
   - 自动刷新（30秒）
   - 即时反馈
   - 颜色编码的状态指示

### 3. 文档

#### ✅ README.md
- 项目介绍和特性列表
- 详细的安装步骤（SDK 编译 + 预编译包）
- 配置指南（Web 界面 + 命令行）
- 使用说明
- 自动更新机制详解
- 故障排除指南
- WebSocket API 示例
- FAQ 常见问题

#### ✅ 项目文件
- `.gitignore` - Git 忽略规则
- `DEVELOPMENT.md` - 本文档

## 技术亮点

### 1. 90 天过期解决方案

**三层防护**:
1. **Cron 定期检查**: 每周自动检查剩余天数
2. **阈值触发**: 剩余天数低于阈值自动更新
3. **手动更新接口**: Web 界面和命令行都支持

**安全更新流程**:
```
检查架构 → 下载到临时目录 → 解压验证 → 停止服务 →
备份旧版本 → 安装新版本 → 验证新版本 → 重启服务
```

### 2. 架构检测和多架构支持

```bash
detect_arch() {
    local machine=$(uname -m)
    case "$machine" in
        aarch64|arm64)  echo "aarch64" ;;
        armv7l|armv7)   echo "armv7" ;;
        x86_64|amd64)   echo "x86_64" ;;
    esac
}
```

### 3. Procd 服务集成

- 自动重启（respawn）
- 配置文件监控（reload trigger）
- 日志集成（syslog）
- 优雅关闭

### 4. 状态监控 API

提供 JSON API：
- `/admin/services/spotify-soloist/status` - 获取完整状态
- `/admin/services/spotify-soloist/update` - 触发更新
- `/admin/services/spotify-soloist/check_days` - 检查剩余天数

## 待优化项目

### 短期改进

1. **更精确的天数检测**
   - 当前依赖日志解析，可能不够准确
   - 考虑从二进制元数据提取构建日期

2. **下载进度显示**
   - Web 界面显示下载进度
   - 使用 curl 的进度回调

3. **更新失败恢复**
   - 如果新版本验证失败，自动回滚
   - 保留多个历史版本

4. **网络检查**
   - 更新前检查网络连通性
   - 提供离线包安装选项

### 长期优化

1. **多实例支持**
   - 支持同时运行多个 Soloist 实例
   - 不同音频输出设备

2. **播放状态集成**
   - 通过 WebSocket API 在 LuCI 显示当前播放
   - 显示专辑封面、歌曲名、艺术家

3. **高级音频配置**
   - EQ 均衡器设置
   - 音频输出设备选择
   - 采样率配置

4. **统计和日志**
   - 播放统计
   - 历史记录
   - 图形化日志查看

5. **升级保护**
   - 在 `/etc/sysupgrade.conf` 添加配置保留
   - 固件升级后自动恢复服务

## 测试计划

### 单元测试

- [ ] 架构检测功能
- [ ] URL 生成逻辑
- [ ] 剩余天数解析

### 集成测试

- [ ] 完整安装流程
- [ ] 服务启动和停止
- [ ] 配置修改和重载
- [ ] 自动更新触发

### 平台测试

- [ ] ARMv7 设备（Raspberry Pi 2）
- [ ] ARMv8 设备（Raspberry Pi 3/4）
- [ ] x86_64 虚拟机
- [ ] 不同 OpenWrt 版本（21.02, 22.03, 23.05）

### 场景测试

- [ ] 首次安装（无二进制文件）
- [ ] 版本更新（有旧版本）
- [ ] 网络中断（下载失败）
- [ ] 磁盘空间不足
- [ ] 过期后启动（退出码 10）

## 已知问题

1. **Spotify 下载链接**
   - 当前使用的是假设的 URL 格式
   - 需要根据实际 Spotify 文档更新
   - 可能需要 API 密钥或认证

2. **剩余天数检测**
   - 依赖日志输出可能不稳定
   - 需要找到更可靠的方法

3. **音频系统依赖**
   - 当前依赖 PulseAudio/PipeWire
   - 可能需要为 ALSA 提供替代方案

## 构建和部署建议

### 本地开发环境

```bash
# 1. 下载 OpenWrt SDK
wget https://downloads.openwrt.org/releases/23.05.0/targets/ramips/mt7621/openwrt-sdk-*.tar.xz
tar xf openwrt-sdk-*.tar.xz
cd openwrt-sdk-*

# 2. 链接包到 SDK
ln -s /path/to/spotify-soloist-openwrt/spotify-soloist package/
ln -s /path/to/spotify-soloist-openwrt/luci-app-spotify-soloist package/

# 3. 编译
make package/spotify-soloist/compile V=s
make package/luci-app-spotify-soloist/compile V=s
```

### CI/CD 建议

使用 GitHub Actions 自动构建多架构包：

```yaml
name: Build Packages

on:
  push:
    branches: [ main ]
  pull_request:
    branches: [ main ]

jobs:
  build:
    strategy:
      matrix:
        arch: [ramips-mt7621, bcm27xx-bcm2711, x86-64]
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      - name: Build for ${{ matrix.arch }}
        run: |
          # 构建脚本
```

## 版本规划

### v1.0.0 (当前)
- ✅ 核心功能
- ✅ 基础 LuCI 界面
- ✅ 自动更新机制
- ✅ 基础文档

### v1.1.0 (计划)
- [ ] 精确的天数检测
- [ ] 下载进度显示
- [ ] 更好的错误处理
- [ ] 更多语言支持

### v2.0.0 (未来)
- [ ] 播放状态集成
- [ ] 高级音频配置
- [ ] 统计和日志功能
- [ ] 多实例支持

## 社区贡献指南

欢迎贡献！请遵循：

1. Fork 项目
2. 创建功能分支 (`git checkout -b feature/AmazingFeature`)
3. 提交更改 (`git commit -m 'Add some AmazingFeature'`)
4. 推送到分支 (`git push origin feature/AmazingFeature`)
5. 开启 Pull Request

### 代码规范

- Shell 脚本使用 POSIX 兼容语法
- Lua 代码遵循 LuCI 风格指南
- 添加适当的注释
- 更新相关文档

## 参考资源

### Spotify Soloist
- [官方文档](https://developer.spotify.com/documentation/soloist)
- [GitHub 仓库](https://github.com/spotify/soloist)

### OpenWrt 开发
- [包开发指南](https://openwrt.org/docs/guide-developer/packages)
- [UCI 系统](https://openwrt.org/docs/techref/uci)
- [Procd Init Scripts](https://openwrt.org/docs/guide-developer/procd-init-scripts)

### LuCI 开发
- [LuCI 文档](https://github.com/openwrt/luci/wiki)
- [示例应用](https://github.com/openwrt/luci/tree/master/applications/luci-app-example)

---

**最后更新**: 2026-10-11  
**维护者**: Your Name

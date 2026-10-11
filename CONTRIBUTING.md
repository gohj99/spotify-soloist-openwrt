# Contributing to Spotify Soloist OpenWrt

感谢你对本项目的关注！我们欢迎任何形式的贡献。

## 如何贡献

### 报告 Bug

如果你发现了 bug，请创建一个 Issue，并包含以下信息：

- **环境信息**
  - OpenWrt 版本
  - 设备型号和架构（ARM/x86_64）
  - 包版本
  
- **问题描述**
  - 清晰的问题描述
  - 重现步骤
  - 预期行为 vs 实际行为
  
- **日志信息**
  ```bash
  # 相关日志
  logread | grep soloist
  ```

- **配置信息**
  ```bash
  # UCI 配置
  uci show spotify-soloist
  ```

### 功能请求

如果你有新功能的想法：

1. 先检查 Issues 是否已有类似请求
2. 创建新 Issue 描述功能需求
3. 说明使用场景和预期效果
4. 如果可能，提供实现思路

### 提交代码

#### 开发流程

1. **Fork 项目**
   ```bash
   # 在 GitHub 上点击 Fork
   git clone https://github.com/YOUR_USERNAME/spotify-soloist-openwrt.git
   cd spotify-soloist-openwrt
   ```

2. **创建功能分支**
   ```bash
   git checkout -b feature/amazing-feature
   # 或
   git checkout -b fix/bug-description
   ```

3. **进行开发**
   - 遵循代码规范（见下文）
   - 添加必要的注释
   - 更新相关文档

4. **测试你的更改**
   ```bash
   # 在实际设备上测试
   ./test.sh
   ```

5. **提交更改**
   ```bash
   git add .
   git commit -m "feat: add amazing feature"
   # 或
   git commit -m "fix: resolve bug in updater script"
   ```

6. **推送到你的 Fork**
   ```bash
   git push origin feature/amazing-feature
   ```

7. **创建 Pull Request**
   - 访问 GitHub 仓库
   - 点击 "New Pull Request"
   - 填写 PR 描述模板

#### Commit Message 规范

使用 [Conventional Commits](https://www.conventionalcommits.org/) 格式：

```
<type>(<scope>): <subject>

<body>

<footer>
```

**Type:**
- `feat`: 新功能
- `fix`: Bug 修复
- `docs`: 文档更新
- `style`: 代码格式（不影响功能）
- `refactor`: 重构
- `test`: 测试相关
- `chore`: 构建/工具配置

**示例:**
```
feat(luci): add playback status display

- Add WebSocket connection to display current track
- Show album artwork in status section
- Add play/pause controls

Closes #123
```

### 代码规范

#### Shell 脚本

- 使用 POSIX 兼容语法
- 使用 4 空格缩进
- 函数命名使用 snake_case
- 添加错误处理
- 使用 `set -e` 在脚本开头

```bash
#!/bin/sh
# Good example

set -e

my_function() {
    local param="$1"
    
    if [ -z "$param" ]; then
        echo "ERROR: parameter required"
        return 1
    fi
    
    # Do something
    echo "Processing: $param"
}
```

#### Lua 代码

- 使用 tab 缩进（LuCI 风格）
- 函数命名使用 snake_case
- 局部变量使用 local
- 遵循 LuCI 的模式

```lua
-- Good example

function action_status()
	local sys = require "luci.sys"
	local status = {}
	
	-- Get status
	status.running = (sys.call("pidof soloist > /dev/null") == 0)
	
	luci.http.prepare_content("application/json")
	luci.http.write_json(status)
end
```

#### Makefile

- 使用 tab 缩进（Makefile 要求）
- 保持简洁清晰
- 添加注释说明非标准配置

```makefile
# Good example

PKG_NAME:=spotify-soloist
PKG_VERSION:=1.0.0
PKG_RELEASE:=1

# Custom configuration for binary download
PKG_SOURCE_URL:=https://example.com/download
```

### 文档更新

如果你的更改影响用户使用，请更新文档：

- **README.md** - 用户指南和基本说明
- **DEVELOPMENT.md** - 开发者文档
- **代码注释** - 复杂逻辑的说明

### Pull Request 检查清单

在提交 PR 前，请确认：

- [ ] 代码遵循项目规范
- [ ] 添加了必要的注释
- [ ] 更新了相关文档
- [ ] 在实际设备上测试过
- [ ] Commit message 遵循规范
- [ ] 没有引入新的警告或错误

### Review 过程

1. 维护者会审查你的 PR
2. 可能会要求修改
3. 讨论和改进
4. 通过后合并到主分支

## 开发环境搭建

### 前置要求

- Linux 或 macOS（Windows 可用 WSL）
- 至少 10GB 可用磁盘空间
- 基本的 Shell 和 Lua 知识

### 搭建步骤

1. **下载 OpenWrt SDK**

```bash
# 选择对应目标的 SDK
wget https://downloads.openwrt.org/releases/23.05.0/targets/ramips/mt7621/openwrt-sdk-23.05.0-ramips-mt7621_gcc-12.3.0_musl.Linux-x86_64.tar.xz

tar xf openwrt-sdk-*.tar.xz
cd openwrt-sdk-*
```

2. **配置 SDK**

```bash
# 更新 feeds
./scripts/feeds update -a
./scripts/feeds install -a

# 安装依赖
sudo apt-get install build-essential libncurses5-dev gawk git \
     ccache gettext libssl-dev xsltproc zip
```

3. **链接项目**

```bash
ln -s /path/to/spotify-soloist-openwrt/spotify-soloist package/
ln -s /path/to/spotify-soloist-openwrt/luci-app-spotify-soloist package/
```

4. **编译**

```bash
# 使用快速构建脚本
SDK_PATH=/path/to/openwrt-sdk ./build.sh
```

### 调试技巧

#### 查看日志

```bash
# SSH 到路由器
ssh root@192.168.1.1

# 实时日志
logread -f | grep soloist

# 历史日志
logread | grep soloist
```

#### 测试更新脚本

```bash
# 在路由器上手动运行
/usr/bin/spotify-soloist-updater

# 检查剩余天数
/usr/bin/spotify-soloist-check --days

# 强制更新
/usr/bin/spotify-soloist-check --force
```

#### 测试 LuCI 界面

```bash
# 清除 LuCI 缓存
rm -rf /tmp/luci-*

# 重启 uhttpd
/etc/init.d/uhttpd restart
```

## 常见问题

### Q: 如何测试多架构？

A: 使用 QEMU 模拟器或实际设备：
- ARMv7: Raspberry Pi 2
- ARMv8: Raspberry Pi 3/4
- x86_64: VirtualBox VM

### Q: 如何处理 Spotify API 变更？

A: 监控官方文档更新，及时调整下载 URL 和参数。

### Q: 可以添加其他音乐服务吗？

A: 本项目专注于 Spotify Soloist。其他服务建议创建独立项目。

## 获取帮助

- **Issues**: 提问和讨论
- **Discussions**: 社区交流
- **Email**: (如果设置了)

## 行为准则

- 尊重他人
- 包容不同意见
- 专注于建设性讨论
- 避免人身攻击

## 许可证

贡献代码即表示你同意以项目的 MIT 许可证发布。

---

再次感谢你的贡献！🎉

# 架构设计文档

## 系统架构

```
┌─────────────────────────────────────────────────────────────┐
│                        OpenWrt 系统                          │
├─────────────────────────────────────────────────────────────┤
│                                                               │
│  ┌────────────────┐                  ┌──────────────────┐   │
│  │  LuCI Web UI   │                  │  UCI 配置系统    │   │
│  │  (Lua/HTML)    │◄─────────────────┤  /etc/config/    │   │
│  └────────┬───────┘                  └────────▲─────────┘   │
│           │                                    │             │
│           │ HTTP API                           │             │
│           ▼                                    │             │
│  ┌────────────────┐                  ┌────────┴─────────┐   │
│  │   Controller   │                  │   Init Script    │   │
│  │   (Lua RPC)    │◄─────────────────┤   (Procd)        │   │
│  └────────┬───────┘                  └────────▲─────────┘   │
│           │                                    │             │
│           │ Shell Exec                         │ Service Mgmt│
│           ▼                                    │             │
│  ┌────────────────────────────────────────────┴─────────┐   │
│  │              管理脚本层                               │   │
│  │  ┌─────────────────┐     ┌─────────────────┐        │   │
│  │  │ Updater Script  │     │  Check Script   │        │   │
│  │  └────────┬────────┘     └────────┬────────┘        │   │
│  └───────────┼──────────────────────┼──────────────────┘   │
│              │                       │                       │
│              ▼                       ▼                       │
│  ┌─────────────────────────────────────────────────────┐   │
│  │           Spotify Soloist 二进制                     │   │
│  │         /usr/sbin/soloist                            │   │
│  └────────┬────────────────────────┬────────────────────┘   │
│           │                        │                         │
│           │ Audio Output           │ Network (mDNS)          │
│           ▼                        ▼                         │
│  ┌─────────────────┐      ┌──────────────────┐             │
│  │  PulseAudio/    │      │  Spotify Connect │             │
│  │  PipeWire       │      │  Protocol        │             │
│  └────────┬────────┘      └────────┬─────────┘             │
└───────────┼──────────────────────────┼────────────────────────┘
            │                          │
            ▼                          ▼
      ┌─────────┐              ┌────────────┐
      │ Speaker │              │  Spotify   │
      │  音频   │              │  Clients   │
      └─────────┘              └────────────┘
```

## 核心组件

### 1. Spotify Soloist 二进制

**位置:** `/usr/sbin/soloist`

**职责:**
- Spotify Connect 协议实现
- 音频流解码和播放
- mDNS 服务广播
- WebSocket API 服务器（可选）

**特点:**
- 专有二进制文件，由 Spotify 提供
- 90 天有效期限制
- 支持 ARMv7, ARMv8/AArch64, x86_64

### 2. Procd Init 脚本

**位置:** `/etc/init.d/spotify-soloist`

**职责:**
- 服务生命周期管理
- 从 UCI 读取配置
- 构建命令行参数
- 进程监控和自动重启

### 3. UCI 配置系统

**位置:** `/etc/config/spotify-soloist`

**配置结构:**
```
spotify-soloist
  └── main                      # 唯一的配置节，类型为 spotify-soloist
      ├── enabled
      ├── device_name
      ├── audio_backend         # auto | pulseaudio | pipewire
      ├── alsa_output           # auto | hw:N | 声卡 id
      ├── pipewire_device
      ├── initial_volume
      ├── data_dir
      ├── cache_dir
      ├── cache_size
      ├── ws_enabled / ws_address / ws_port
      ├── auto_update / update_threshold / check_update_cron
      └── verbose / run_as_root
```

### 4. 自动更新系统

#### 4.1 Updater 脚本

**位置:** `/usr/bin/spotify-soloist-updater`

**工作流程:**
1. 检测系统架构
2. 构建下载 URL
3. 下载到临时目录
4. 解压和验证
5. 停止服务
6. 备份当前版本
7. 安装新版本
8. 验证新版本
9. 重启服务
10. 清理临时文件

#### 4.2 Check 脚本

**位置:** `/usr/bin/spotify-soloist-check`

**功能:**
- 解析剩余有效天数
- 与阈值比较
- 触发更新（如启用）

**触发机制:**
- Cron 定期检查
- 手动触发
- 阈值触发

### 5. LuCI Web 界面

#### Controller
- 路由管理
- API 端点
- 业务逻辑

#### CBI Model
- 配置表单
- 数据验证
- UI 组件

#### Status Template
- 实时状态显示
- 操作按钮
- 异步更新

## 数据流

### 启动流程

```
用户启用服务
  ↓
UCI 配置更新
  ↓
Procd 触发 reload
  ↓
Init 脚本读取配置
  ↓
构建启动参数
  ↓
启动 Soloist 进程
  ↓
mDNS 广播
  ↓
设备可见
```

### 更新流程

```
Cron 触发
  ↓
检查剩余天数
  ↓
是否低于阈值？
  ↓ Yes
下载新版本
  ↓
停止服务
  ↓
备份旧版本
  ↓
安装新版本
  ↓
验证
  ↓
重启服务
```

## 安全考虑

### WebSocket API
- 仅绑定 127.0.0.1
- 不对外暴露
- 无内置认证

### 自动更新
- HTTPS 下载
- 二进制验证
- 保留备份
- 原子替换

### UCI 配置
- LuCI ACL 控制
- rpcd 权限管理
- 标准 OpenWrt 认证

## 性能优化

### 存储优化
- 调整缓存大小
- 定期清理日志
- 删除旧备份

### 网络优化
- 较低比特率
- 限制缓存

### CPU优化
- Procd 进程管理
- 自动优先级调整

## 调试技巧

### 启用详细日志
```bash
uci set spotify-soloist.main.log_level='debug'
uci commit && /etc/init.d/spotify-soloist restart
logread -f | grep soloist
```

### 手动测试更新
```bash
/usr/bin/spotify-soloist-check --days
/usr/bin/spotify-soloist-updater
```

### 检查进程状态
```bash
pidof soloist
ps | grep soloist
netstat -tuln | grep 9090
```

---

**最后更新:** 2026-10-11

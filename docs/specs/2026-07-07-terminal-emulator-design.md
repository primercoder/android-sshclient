# 终端仿真器模式设计

## 目标
在 SSH 会话中增加 xterm 兼容的终端仿真器模式，用户可在气泡聊天和全屏终端间切换。

## 架构
```
SSH Server ←→ SSHClient (SshClientService, 共享)
               ├── client.execute()  → 气泡模式 (不变)
               └── client.shell()    → SshTerminalService → TerminalView (xterm)
```

- `client.execute()` 和 `client.shell()` 是不同的 SSH channel，互不干扰
- 同一 SSH 连接可同时存在气泡命令和终端 shell

## 文件变更

### 新增文件

#### `lib/services/ssh/ssh_terminal_service.dart`
管理持久化 shell session 生命周期：
- `start(client, terminal)` → 调用 `client.shell(pty:)`，绑定 stdin/stdout
- `stop()` → 关闭 shell channel，SSHClient 保持连接
- 处理 resize 事件

#### `lib/ui/widgets/chat/terminal_screen.dart`
全屏终端视图，包含：
- `TerminalView(terminal)` 占满可用空间
- 底部快捷键栏（Tab, Esc, ^C, ^D, ↑, ↓, ←, →）
- 可拖动浮动圆形按钮返回气泡模式

### 修改文件

#### `pubspec.yaml`
添加 `xterm: ^4.0.0`

#### `lib/ui/pages/chat_page.dart`
- 新增 `_inTerminalMode` 状态
- 连接后在右下角添加可拖动的浮动按钮（terminal 图标）
- 点击进入 `TerminalScreen`
- 进入时在 chat 记录添加 "已进入终端模式" 系统消息
- 返回时清除 `_inTerminalMode`，显示气泡视图

## 快捷键栏设计
```
┌──────────────────────────────────────────────────┐
│  Tab  │  Esc  │  ^C  │  ^D  │  ↑  │  ↓  │  ←  │  →  │
└──────────────────────────────────────────────────┘
```
每个按钮直接向 SSH session 发送对应控制序列：
- Tab → `\t` (0x09)
- Esc → `\x1b`
- ^C → `\x03`
- ^D → `\x04`
- ↑/↓/←/→ → ANSI escape sequences

## 交互流程
1. 用户进入聊天页 → SSH 连接 → 右下角出现可拖动的终端按钮
2. 点击终端按钮 → 添加系统消息 "已进入终端模式" → 显示 TerminalScreen
3. TerminalScreen 全屏显示终端 + 底部快捷键
4. 拖动按钮回到气泡模式 → 关闭 shell channel → 显示气泡视图
5. SSH 连接全程保持，不中断

## 生命周期
- Shell channel 在进入终端时创建，返回气泡时关闭
- SSH 连接断开时自动关闭所有 channel
- 气泡模式的 `execute()` 和终端模式的 `shell()` 互不影响

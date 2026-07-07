# SSH Client

基于 Flutter 构建的 Android SSH 客户端，支持密码和 Ed25519 公钥认证、会话管理、交互式命令执行、SCP 文件传输、局域网扫描。

## 功能特性

- **SSH 连接** — 密码认证 + Ed25519 公钥认证，支持密钥生成/导入/查看/上传到主机
- **命令执行** — 交互式命令终端，自动追踪工作目录
- **终端仿真** — 支持全屏 xterm 兼容终端模式，底部快捷键栏，可拖动切换按钮（适合 vim/htop 等需要持续终端的命令）
- **目录浏览** — 顶栏显示当前路径，点击浏览子目录
- **文件传输 (SCP)** — 通过 SSH 通道上传/下载文件，实时进度显示
- **会话管理** — 离开聊天页可保持会话活跃，历史回放
- **局域网扫描** — TCP 端口扫描，支持暂停/继续/停止，结果一键添加为主机
- **快捷命令** — 可自定义的命令芯片，支持拖拽排序
- **主机管理** — 已保存主机编辑/删除，连接状态实时指示
- **主题** — 深色模式切换，Material 3 设计
- **公钥认证** — 内置密钥管理器，支持 Ed25519 密钥生成、PEM 导入导出

## 运行截图

|  |  |
|---|---|
| ![主页](assets/1_init_page.png) | ![目录浏览](assets/5_top_directory.png) |
| ![快捷命令编辑](assets/6_quick_cmd_edit.png) | ![会话交互](assets/7_session_interactions.png) |

## 技术栈

| 组件 | 技术 |
|-----------|-------|
| 框架 | Flutter 3.41.9 |
| 语言 | Dart 3.11.5 |
| SSH | dartssh2 |
| 状态管理 | Riverpod |
| 数据库 | SQLite (sqlite3) |
| 终端仿真 | xterm.dart |
| 公钥加密 | pinenacl (Ed25519) |
| 最低 Android API | 34 |
| 目标 Android API | 35 |

## 架构

```
主页 (主机列表 + 局域网扫描)
  └── 聊天页
       ├── 路径栏
       ├── 消息列表（命令/输出/系统/文件传输）
       │    └── 右下角浮动按钮 ↔ 终端模式
       ├── 快捷命令芯片
       ├── 文件面板（上传/下载）
       └── 输入栏

终端模式 (全屏 xterm 仿真终端)
  ├── TerminalView（VT100/xterm-256color）
  ├── 底部快捷键栏（Tab, Esc, ^C, ^D, ↑↓←→）
  └── 可拖动返回按钮（→ 聊天页）
```

## 安全说明

- SSH 密码以明文存储在本地 SQLite 中（建议启用设备级加密）
- Ed25519 私钥存储在应用内部目录，不对外导出
- Android 14+ 使用 Storage Access Framework (SAF) 下载/上传文件
- **发布构建**默认使用调试密钥库 — 发布前请通过 `android/key.properties` 配置发布密钥库

## 构建

### 环境要求

| 工具 | 版本 |
|------|------|
| Flutter | 3.41.9 |
| Dart | 3.11.5 (随 Flutter SDK 捆绑) |
| Java (JDK) | 17 或 21 |
| Android Gradle Plugin | 8.11.1 |
| Gradle | 8.14 (Wrapper) |
| Kotlin | 2.2.20 |

### 安装步骤

1. **安装 Flutter SDK** — 从 [flutter.dev](https://flutter.dev/docs/get-started/install) 下载 Flutter 3.41.9 或更高版本，确保 `flutter` 已加入 `PATH`。

2. **安装 JDK 17 或 21** — 推荐 [OpenJDK](https://openjdk.org/) 或 [Amazon Corretto](https://aws.amazon.com/corretto/)：
   ```bash
   # Ubuntu/Debian
   sudo apt install openjdk-21-jdk

   # macOS (Homebrew)
   brew install openjdk@21
   ```

3. **配置 Android SDK** — 通过 Android Studio SDK Manager 安装，或命令行指定：
   ```bash
   flutter config --android-sdk /path/to/android-sdk
   ```

4. **接受许可协议**：
   ```bash
   flutter doctor --android-licenses
   ```

5. **验证环境**：
   ```bash
   flutter doctor
   ```

### 构建 APK

```bash
flutter pub get
flutter build apk --release
```

构建产物：`build/app/outputs/flutter-apk/app-release.apk`

> 发布前请配置 `android/key.properties` 发布密钥库。

## 开源协议

本项目基于 MIT 协议开源。详见 [LICENSE](LICENSE) 文件。

## 图标来源

部分设备图标由 mobirise 提供，来源于 <a href="https://icon-icons.com/zh/authors/581-mobirise">Icon-Icons.com</a>。

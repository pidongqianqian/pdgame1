# Android 导出环境配置与发布指南

本文档记录《像素深渊》在 macOS 上配置 Godot 4 Android 导出环境的完整过程，以及后续每次导出 APK 的操作步骤。

---

## 环境信息

| 项目 | 版本 |
|------|------|
| 操作系统 | macOS（Apple Silicon / Intel 均适用） |
| Godot | 4.6.1.stable |
| JDK | OpenJDK 17（Homebrew） |
| Android SDK | Build-Tools 36.1.0 / Platform API 34 |
| Android minSdk | 24（Android 7.0） |
| targetSdk | 34（Android 14） |

---

## 一、初次环境配置（只需做一次）

### 1. 安装 JDK 17

```bash
brew install openjdk@17

# 加入系统路径
echo 'export PATH="/opt/homebrew/opt/openjdk@17/bin:$PATH"' >> ~/.zshrc
echo 'export JAVA_HOME="/opt/homebrew/opt/openjdk@17"' >> ~/.zshrc
source ~/.zshrc

# 验证
java -version
# 预期输出：openjdk version "17.0.x"
```

### 2. 安装 Android SDK

通过 Android Studio 安装（推荐），或使用命令行工具：

**方法 A：Android Studio**
1. 下载安装 [Android Studio](https://developer.android.com/studio)
2. 启动后，菜单 `Tools → SDK Manager`
3. SDK Platforms：勾选 **Android 14.0 (API 34)**
4. SDK Tools：确认已安装 `Build-Tools 34+`、`Platform-Tools`

**方法 B：纯命令行（轻量）**

```bash
# 下载 Command Line Tools：https://developer.android.com/studio#command-tools
mkdir -p ~/Library/Android/sdk/cmdline-tools
unzip ~/Downloads/commandlinetools-mac-*.zip -d ~/Library/Android/sdk/cmdline-tools
mv ~/Library/Android/sdk/cmdline-tools/cmdline-tools \
   ~/Library/Android/sdk/cmdline-tools/latest

# 加入 PATH
echo 'export ANDROID_HOME="$HOME/Library/Android/sdk"' >> ~/.zshrc
echo 'export PATH="$ANDROID_HOME/cmdline-tools/latest/bin:$ANDROID_HOME/platform-tools:$PATH"' >> ~/.zshrc
source ~/.zshrc

# 安装必要组件
yes | sdkmanager --licenses
sdkmanager "build-tools;34.0.0" "platforms;android-34" "platform-tools"
```

### 3. 加入 adb 路径（如未自动配置）

```bash
echo 'export PATH="$HOME/Library/Android/sdk/platform-tools:$PATH"' >> ~/.zshrc
source ~/.zshrc

# 验证
adb version
```

### 4. 生成 Debug 签名 Keystore

```bash
keytool -genkey -v \
  -keystore /Users/yangguang/pdgame1-debug.keystore \
  -alias pdgame1 \
  -keyalg RSA \
  -keysize 2048 \
  -validity 10000 \
  -storepass android \
  -keypass android \
  -dname "CN=PDGame, O=pdgame, C=CN"
```

生成的文件路径：`/Users/yangguang/pdgame1-debug.keystore`

> 正式发布时需要另外生成 Release Keystore，并妥善保管（丢失后无法更新已上架应用）。

### 5. 在 Godot 编辑器中配置

打开 Godot → **Editor → Editor Settings → Export → Android**，填入：

| 设置项 | 值 |
|--------|-----|
| `Java SDK Path` | `/opt/homebrew/opt/openjdk@17` |
| `Android SDK Path` | `/Users/yangguang/Library/Android/sdk` |
| `Debug Keystore` | `/Users/yangguang/pdgame1-debug.keystore` |
| `Debug Keystore User` | `pdgame1` |
| `Debug Keystore Pass` | `android` |

### 6. 安装 Godot Android 导出模板

**Editor → Manage Export Templates → Download and Install**

等待下载完成（约 500MB）。模板会安装到：
```
~/Library/Application Support/Godot/export_templates/4.6.1.stable/
```

安装完成后应包含：`android_debug.apk`、`android_release.apk`、`android_source.zip`

---

## 二、项目 Android 导出配置

项目的 Android 导出预设已写入 `export_presets.cfg`（`preset.2`），主要参数：

```ini
[preset.2]
name="Android"
platform="Android"
export_path="build/android/像素深渊.apk"

[preset.2.options]
package/unique_name="com.pdgame.pixelabyss"
package/name="像素深渊"
gradle_build/min_sdk=24
gradle_build/target_sdk=34
screen/orientations=2        # 强制横屏
screen/immersive_mode=true   # 全屏沉浸模式
```

如需在 Godot 导出界面中查看/修改，打开 **Project → Export**，若列表为空，点 **Add... → Android** 即可载入配置。

---

## 三、每次导出 APK 的步骤

### 方法 A：通过 Godot 编辑器导出

1. 打开 **Project → Export**
2. 选中左侧 **Android** 预设
3. 确认导出路径为 `build/android/像素深渊.apk`
4. 点击 **Export Project**（导出项目，不调试）或 **Export with Debug**（带调试信息）
5. 等待构建完成

### 方法 B：命令行导出（适合自动化）

```bash
cd /Users/yangguang/code/tools/pdgame1

# 找到 Godot 可执行文件路径（根据实际安装位置调整）
GODOT="/Applications/Godot.app/Contents/MacOS/Godot"

# 导出 Debug APK
$GODOT --headless --export-debug "Android" build/android/像素深渊.apk
```

---

## 四、安装到手机测试

### 前置条件：开启手机 USB 调试

1. 手机进入 **设置 → 关于手机**，连续点击「版本号」7 次，开启开发者模式
2. **设置 → 开发者选项 → USB 调试** 开启
3. 用 USB 数据线连接电脑，手机弹出授权提示选「允许」

### 安装 APK

```bash
# 确认设备已连接
adb devices
# 预期输出：
# List of devices attached
# XXXXXXXX    device

# 安装 APK
adb install build/android/像素深渊.apk

# 如果之前已安装旧版本，使用 -r 覆盖安装
adb install -r build/android/像素深渊.apk
```

### One Click Deploy（最快捷）

USB 连接手机后，Godot 工具栏右上角会出现手机图标，点击即可直接推送到设备运行（无需手动导出）。

---

## 五、常见问题

### Q: Project → Export 看不到 Android 选项
A: 导出模板未安装。执行 **Editor → Manage Export Templates → Download and Install**。

### Q: adb devices 显示设备但状态是 `unauthorized`
A: 手机屏幕上有 USB 调试授权弹窗，点「允许」即可。

### Q: 导出时报 `Java not found`
A: 检查 Editor Settings 中 `Java SDK Path` 是否正确，应为 `/opt/homebrew/opt/openjdk@17`（不是 bin 目录）。

### Q: APK 安装后闪退
A: 用以下命令查看崩溃日志：
```bash
adb logcat | grep -E "FATAL|godot|pixelabyss"
```

### Q: 以后要上架 Google Play 需要什么
A: 需要重新生成 **Release Keystore**（区别于 Debug），并在导出时使用 Release 签名。Release Keystore 必须妥善备份，丢失后将无法更新已上架的应用。

---

## 六、相关路径速查

| 用途 | 路径 |
|------|------|
| Android SDK | `~/Library/Android/sdk` |
| Godot 导出模板 | `~/Library/Application Support/Godot/export_templates/4.6.1.stable/` |
| Debug Keystore | `/Users/yangguang/pdgame1-debug.keystore` |
| APK 输出 | `项目根目录/build/android/像素深渊.apk` |
| JDK 17 | `/opt/homebrew/opt/openjdk@17` |

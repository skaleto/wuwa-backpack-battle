# iPhone 原生试玩包

## 当前状态（2026-10-30）

Godot iOS Xcode 工程已导出，但**尚未生成可安装的签名 App / IPA，也未完成真机试玩**。

- 工程：`build/ios-preview/xcode/SolarisBrawl.xcodeproj`。
- ARM64、iPhone、横屏，最低 iOS 15；使用现有兼容性渲染器。最低系统值为构建配置，不代表已测试这些设备。
- Bundle ID：`game.solarisbrawl.demo`；版本 `0.1.0`，构建 `138.1`。
- 图标暂用游戏现有小幽灵图案；正式发行图标及隐私声明仍需检查。
- 资源随 App 安装；PCK 约 551 MiB，不在首次启动下载网页 PCK。App 最终安装体积待 Xcode 编译后测量。
- 隔离暂存，仅调整移动端导出设置、应用图标和资源压缩；未改桌面/Web 项目配置、玩法、素材原字节、存档或匹配池。

## 已验证

- 官方 Godot 4.7.2 导出模板整包 SHA-512 一致，提取 iOS 模板。
- Godot iOS 导出修正图标后退出码 0。
- 脱离源码对导出 PCK 验证：486 个原始文件摘要一致、405 张图片可解码、255 个轮廓缓存无损还原，错误 0。
- 当前规则摘要仍为 `16cf6ae5e46b9328761bf304624cd172bbf74e7da6f6bcc0a639e7c7ee46e82f`。

## 当前阻塞与继续步骤

本机 Xcode 26.6 的首次初始化未完成，`xcodebuild -checkFirstLaunchStatus` 返回 69。实际编译返回 70：CoreSimulator 1051.50 低于所需 1051.55，并提示 iOS 26.5 平台未安装。组件安装需要本机管理员密码；已配对的 iPhone 当前为 unavailable。

1. 在本机终端执行 `sudo xcodebuild -runFirstLaunch`，由用户在本机输入密码。
2. 在 Xcode Settings > Components 确认 iOS 平台支持可用；若仍提示缺少则安装对应组件。当前磁盘空间较紧，先核对安装所需容量，不自动删除其他项目。
3. 连接并解锁 iPhone、信任这台 Mac，按设备要求开启开发者模式。
4. 打开导出的 Xcode 工程，核对现有开发团队，自动签名后 Build/Run。证书存在不代表描述文件及账号授权均已验证。
5. 检查横屏安全区、文字可读性、拖放/旋转操作、密集战斗内存和性能、后台恢复、在线上传与匹配。

现有输入以鼠标为主，本次仅启用触控模拟鼠标；右键旋转等操作尚未做手机交互适配。编译成功也不能视为手机体验验收完成。

## 可复现导出

修复 Xcode 后，从新的暂存/输出目录执行：

```bash
python3 tools/build_ios.py \
  --stage /absolute/new-ios-runtime \
  --output /absolute/new-ios-xcode \
  --team-id YOURTEAMID
```

团队标识通过参数传入，不包含私钥、账户密码或描述文件；使用同一台 Mac 的签名配置。此命令只导出工程并校验资源，不上传 TestFlight/App Store。

现有工程继续编译（依赖已就绪的 Apple 开发账号）：

```bash
xcodebuild -project build/ios-preview/xcode/SolarisBrawl.xcodeproj \
  -scheme SolarisBrawl -configuration Debug \
  -destination 'generic/platform=iOS' \
  -derivedDataPath build/ios-preview/DerivedData \
  -allowProvisioningUpdates build
```

签名 App 可部署到其描述文件允许的设备；不能把未签名包改扩展名为 IPA 后当成可直接安装版。对外邀请用户安装需另行确定 TestFlight 或其他合规分发方式。

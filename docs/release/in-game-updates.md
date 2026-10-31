# 游戏内更新与悬停详情

## 玩家交互

物品上停留约 0.25 秒显示详情，移开收起；点击仍然固定卡片并保留合成配方入口。拿起、右键旋转、放下不变。悬停不会播放声音、保存、暂停战斗或购买物品。

发布客户端启动后后台检查，设置中也可手动检查。发现新版时主界面显示入口；玩家主动下载，可返回游戏。下载和校验完成后，在当前一局结束、回到主界面时重启更新。正在进行或等待网络结果的对局不换版本。第一次升级需要手动安装一次带更新器的新客户端：既有 demo.3 二进制没有这一能力，不能自行增加入口。

Windows 和 macOS 支持资源补丁及完整客户端更新。Web 使用刷新页面进入新部署；iOS 不下载可执行更新。编辑器/源码运行不连接发布更新服务，不给开发目录安装补丁。

## 边界

- `scripts/update/update_manifest.gd`：验证签名、版本、来源和平台；不读存档。
- `update_store.gd`：私有更新缓存、原子指针、试启动确认与回退，不写玩家数据。
- `bootstrap.gd`：先验包、挂包，再动态加载游戏；只能使用真正发布模板的 `template` 标记，Godot 4.7 没有启用 `standalone` 标记。
- `update_client.gd`：异步检查/下载、后台校验、状态与操作。展示只收值和回调。
- `tools/updater/`：引擎/启动器变化时替换完整安装，先校验并解包，准备成功后才通知游戏退出。未知安装文件、无写权限等失败保持游戏运行，已下载包可手动安装。

更新源只保存公开签名清单和包；客户端包含公钥，没有私钥或云密钥。信任 HTTPS 固定域名，逐跳核验跳转，再用 RSA/SHA-256 核验清单和下载字节。下载失败从头重试，不宣称断点续传。更新目录保存当前、前一健康版、待启用版；只有确认成功后清理识别出的过期包，未知文件保留。完整更新保留一个安装目录备份。

补丁首次启动没有完成确认时，下次启动回退。完整更新助手在新进程退出且未确认时恢复旧版；若进程仍在运行而确认超时，保留两份，不强行覆盖运行中的文件。Windows 助手已交叉编译，仍需 Windows 实机验收；macOS 已做原生助手更新/回退测试。macOS 发行包为临时签名，未做 Apple 开发者签名或公证。

## 后续发布

`data/update-channel.json` 是这代完整客户端的不可变信任配置。私钥必须保存在仓库之外，不纳入构建。每次递增 `sequence`，玩家可读版本放在 `version`。不要修改历史包；先上传版本化产物，验证下载，再最后发布 `updates/stable.json`。

```bash
# 新目录，只包含 runtime-files.json 列出的资源
python3 tools/build.py --stage /abs/new-runtime
# 完整包带原生助手和安装清单，具体命令见 tools/updater/README.md
python3 tools/updater/build.py build --output build/updater
# 补丁始终对同一代原始完整 PCK 累积生成，不串联所有历史补丁
python3 tools/build_update.py patch --stage /abs/new-runtime --base-pack /abs/base.pck --inventory /abs/base-manifest.json --platform Windows --output /abs/update.pck
# spec 中每个平台产物提供 file、url、kind；签名前自动计算 bytes/sha256
python3 tools/build_update.py sign --spec /abs/spec.json --key /private/release-signing.pem --output /abs/stable.json
```

启动脚本、信任配置、底层缓存协议或引擎设置变更必须发布完整客户端，构建工具拒绝当成普通补丁。平台产物可在 `patch.full` 中带完整包：旧基础版本或运行时不匹配时，客户端选完整包。完整包必须是一层独立目录，包含 `archive_root`、相对 `executable` 与安装清单。macOS 清单位于 `Contents/Resources/update-install.json`，Windows 位于安装目录根。

签名规范：外层 JSON 为 Base64 的 `payload` 和 `signature`；签名覆盖解码后 payload 的原始 UTF-8 字节。payload 包含 `schema:1`、整数 `sequence`/`runtime`、`version`、`base_id`、短 `notes`、`platforms`。Windows/macOS 的产物为 `kind:patch|full`、HTTPS `url`、可选 `fallback_url`、`bytes`、`sha256`；Web 为 `kind:web` 和部署网址。完整包另含归档根和可执行文件相对路径。

## 验证入口

```bash
python3 tools/check.py --jobs 2
python3 -m unittest discover -s tests -p 'test*update*.py'
(cd tools/updater && go test ./...)
python3 tools/performance.py --tag update-hover --full
python3 tools/release_manifest.py --check
```

真实 TLS 夹具使用临时密钥、证书与独立缓存；不访问生产玩家数据。原生视觉截图由 `tests/visual/update_hover_preview.gd` 的隐藏不可聚焦画布生成。测试、日志、签名私钥和更新任务文件不进入安装包。

## 本次验收（0.2.0-demo.1）

167/167 项回归、3 项更新发布/HTTPS 测试、11 组原生更新助手测试通过。隐藏原生画布验收了悬停与固定详情、更新入口和下载状态；真实 Mac 完整包在独立 QA 档位下启动通过。密集战斗打开悬停详情时，更新耗时 P95 为 0.559 ms，绘图 P95 为 9.456 ms，冻结战果保持不变。运行规则哈希未改变。

当前签名桌面清单已经部署至国内更新服务并实测通过。完整 Windows/macOS 首次安装包本轮只在本地生成，尚未替换 GitHub 或已有国内下载链接；Web 线上部署也没有改动。未来发布新版时上传对应产物并最后切换清单即可。保管并独立备份发布侧签名私钥；丢失私钥需要重新分发可信基础客户端。

## 整理补丁（0.2.0-demo.2）

已发布到同一国内 stable 更新通道，序号 14101，沿用不可变基础 desktop-v141。Windows/macOS 补丁均为 253,948 字节（约 248 KiB）；相对基础版本仅替换游戏控制脚本，并加入口袋整理模块及其资源 UID。完整客户端、Web 和 GitHub Releases 本轮没有重新发布。

整理期间仅编辑口袋布局草稿，物品灰显固定；点击「完成整理」才原子提交，无完整覆盖的物品落入储物箱。Esc 取消草稿；重叠、越界、过期请求、冻结在线状态和保存失败不会破坏真实库存。普通口袋移动的原有行为保持。

168/168 回归通过，隐藏原生 SubViewport 检查了整理前、草稿、完成和落箱画面；目录指纹保持不变，公开源码与发布补丁隐私扫描通过。使用原始 0.2.0-demo.1 的 Windows/macOS PCK，在 Mac Godot 运行器中分别完成线上检查、下载、签名与摘要验证，再以新进程挂载补丁，验证新整理行为。未将该结果表述为 Windows 实机重启验证。

玩家使用带更新器的 0.2.0-demo.1 客户端，在设置中检查更新、下载补丁，完成尚未结束的对局后回主界面「重启并更新」。更新后版本显示 0.2.0-demo.2；不需要再次下载完整 ZIP。补丁与玩家存档、安装身份分开存放。

## 更新提示与结算反馈（0.2.0-demo.3）

序号 14102 的 Windows/macOS 累积补丁已发布到 stable，均为 345,628 字节（约 338 KiB）。发现新版后在主界面安全空闲时主动提示一次，可稍后处理。菜单与更新页可确认结束未完成对局：核对存档、保留恢复备份与已完成战斗记录后移走活动存档，不伪造失败，不影响其他模式或安装身份。招募页也可返回主界面。

HUD 分别显示回合、奖杯和剩余红心；结算按共享结果增量投影奖杯弹出/飞入或红心碎裂/灰显，实际结算仍只走原有应用层。169/169 回归、原生隐藏截图、旧 Windows/macOS 资源包的线上下载/校验/新进程挂载及结束本局验证通过。Windows 原生界面的安装重启仍需实机验收。

另构建 Windows 完整包供尚未具备“结束本局”的旧客户端替代安装。完整包沿用同代引擎、信任公钥和 base_id，但其内置配置序号/版本提升至 14102 / 0.2.0-demo.3，避免新安装误加载更旧的缓存补丁。源码不可变配置与原始 demo.1 基线保持原样，后续累积补丁仍针对 demo.1 构建，不能用新完整包的 inventory 替代原始基线。

## V2 完整升级

V2 / 0.2.0 使用序号 14105、基线 `desktop-v142`，包含原生图标与启动组件变更。首次升级发布签名的 `full` 安装包，不把新基线作为旧客户端的资源补丁。三端附件先发布并验证，再替换 `updates/stable.json`；旧桌面客户端接受跨基线完整升级。新局口袋规则独立匹配，旧局不迁移。

# 索拉里斯大乱斗

鸣潮题材的非官方二创背包自动战斗 Demo，使用 Godot 4.7.2。通过购买、摆放、星位联动、连续合成和队友招募构建阵容，支持独立的人机与异步在线对战模式。

当前版本 **V2 / 0.2.0**。支持悬停查看详情、点击固定详情、游戏内检查更新，以及固定物品后调整口袋的整理模式。本次新增小口袋差异效果、商店回收箱，并加强胜负反馈和战斗状态栏，见 [V2 发行说明](docs/release/v2.md)。旧局和历史战斗保留原规则，新局使用独立的口袋规则与在线匹配池。

## 获取和启动

**本机试玩统一入口：`releases/V2/macOS/索拉里斯大乱斗.app`，也可双击根目录 `START.command`。** Windows 和 Web 同在 `releases/V2`，只保留最新一套。本地只保留最新 V2；发布包与源码对应同一个版本标签。构建与发布流程见 [本地 V2](docs/release/local-v2.md)。

玩家下载：[V2 三端 Release](https://github.com/skaleto/wuwa-backpack-battle/releases/tag/v0.2.0)、[Windows 国内下载](https://clear-raccoon-d2gqs87oabfed2a47-1302322545.tcloudbaseapp.com/downloads/v0.2.0/SolarisBrawl-V2-Windows-x86_64.zip)、[macOS 国内下载](https://clear-raccoon-d2gqs87oabfed2a47-1302322545.tcloudbaseapp.com/downloads/v0.2.0/SolarisBrawl-V2-macOS-universal.zip)。Windows/macOS 包无需安装 Godot；Web 附件是需要 HTTP(S) 托管的部署包。[网页试玩](https://clear-raccoon-d2gqs87oabfed2a47-1302322545.tcloudbaseapp.com/index.html)。启动方式和签名状态见 [三端发布说明](docs/release/three-platform.md)。

需要 Godot 4.7.2 与 Git LFS，素材通过 Git LFS 管理。

```bash
git lfs install
git clone git@github.com:skaleto/wuwa-backpack-battle.git
cd wuwa-backpack-battle
git lfs pull
godot --editor --path .
```

开发时在编辑器运行主场景，或执行 `godot --path .`。本机试玩双击 `START.command`，它只打开 `releases/V2` 中的 Mac 完整客户端，无需 Godot。自动生成的源码 ZIP 可能只包含 LFS 指针，不能视为完整可运行包。安装包发布至 [Releases](https://github.com/skaleto/wuwa-backpack-battle/releases)，不作为普通 Git 文件提交。

## 目录约定

目录按功能组织；版本号仅保留在兼容数据、冻结用例及必要的规则实现中。

```text
scripts/
  inventory/   # 物品实例、空间、背包与收纳事务
  crafting/    # 配方、精确材料、合成计划与落点
  battle/      # 战斗模拟、事件与现有版本继承链
  shop/        # 供给、概率、经济与商店操作
  party/       # 角色、招募与队友能力
  ui/          # 画面、输入适配、动效与只读展示
  online/      # 安装身份、异步协议、匹配与上传队列
  update/      # 签名更新、缓存与启动切换
  storage/     # 存档、归档与持久化
  run/         # 局内生命周期与统一提交
  compat/      # 仍需运行的历史校验与迁移适配
  data/        # 目录读取与当前规则投影
assets/
  items/       # 运行物品图像
  characters/  # 运行角色与头像
  ui/          # 运行界面与袋体素材
  audio/       # 运行声音
  vfx/         # 运行特效
  fonts/       # 运行字体
  generated/   # 运行所需的离线生成资源
data/compat/  # 冻结历史目录与兼容数据
tests/
  regression/  # 逻辑与行为回归
  fixtures/    # 不可重录的冻结输入/期望
  visual/      # 隐藏原生画布与视觉检查
  scenarios/   # 真实操作轨迹与性能案例
tools/
  check.py     # 稳定验证入口
  build.py     # 稳定构建入口
  assets/      # 素材处理与离线生成
  legacy/      # 仍需保留的版本工具
art_sources/  # 参考、原始工程与非运行素材
services/pvp_signer/  # 服务端凭证服务
docs/         # 当前索引、历史记录与必要证据
```

目录按责任分，不按“版本号是否旧”决定删除。当前战斗继承链仍是运行依赖，兼容数据和冻结夹具也是契约。本轮不重写战斗引擎，不重录快照，不改变资源原字节。根规范入口：[工作准则](AGENTS.md)、[开发规范](DEVELOPMENT.md)、[设计准则](DESIGN_PRINCIPLES.md)；历史与证据见 [docs 索引](docs/README.md)。

## 验证与构建

先用 Godot 导入工程。`GODOT` 可指定引擎可执行文件；macOS 默认 `/Applications/Godot.app/Contents/MacOS/Godot`。本轮统一的稳定入口为：

```bash
python3 tools/check.py --jobs 2
python3 tools/build.py --stage /abs/new --pack
```

`/abs/new` 替换为不存在的绝对目录。V2 发布前重新运行的游戏回归为 170/170；完整包资源、签名更新清单和隐私扫描通过。服务端仅追加新规则池，健康检查通过。测试默认无头、独立 `qa-*` 存档；需要图形时用隐藏不可聚焦原生画布，不抢用户焦点。历史版本工具不应被随手运行来覆盖当前目录或冻结数据。

凭证服务独立验证：

```bash
python3 -m venv services/pvp_signer/.venv
services/pvp_signer/.venv/bin/pip install -r services/pvp_signer/requirements.txt
services/pvp_signer/.venv/bin/python -m unittest discover -s services/pvp_signer/tests -v
```

构建仅复制运行依赖，保留所需原图/音频字节，排除测试、文档、服务端、艺术源文件及凭据。PCK 须在源码目录外验证。Windows、macOS、Web 导出仍需匹配的 Godot 模板；完整三端包、签名公证及 Windows/Web 真机体验需要独立验收。更多发行约定见 [GitHub 与产物说明](docs/release/github.md)。

长期云秘密仅留服务器；客户端只持安装凭据、会话和限时票据。客户端计算的异步玩法不提供权威反作弊保证。不得将真实玩家凭据写入测试输出或产物。

## 素材与许可

见 [CREDITS.md](CREDITS.md) 及各素材目录来源/许可记录。角色、武器与声骸权利属于原权利人，本项目非官方；署名不代表已取得公开发行或商业使用授权。仓库未对全部代码与素材统一授予开源许可证。

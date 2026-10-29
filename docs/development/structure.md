# 项目结构

2026-10-29：本轮目录迁移，不调整玩法、数值、素材表现或存档协议。

## 从哪里开始

| 要修改的内容 | 入口 |
| --- | --- |
| 游戏启动与页面编排 | `main.tscn` → `scripts/game.gd` |
| 物品与数值 | `data/catalog.json`、`data/items/` → `scripts/data/` |
| 购买、合成、摆放 | `scripts/shop/`、`crafting/`、`inventory/` |
| 战斗与招募 | `scripts/battle/`、`party/` |
| 界面与动效 | `scripts/ui/`，内部按 items、pockets、party、battle 等用途分组 |
| 保存与在线 | `scripts/storage/`、`online/`，整局提交在 `scripts/run/` |
| 图片与音效 | `assets/`，按 items、characters、ui、audio、vfx、fonts 分类 |
| 素材登记 | `assets/manifest.json`；离线缓存在 `assets/generated/` |
| 服务端 | `services/pvp_signer/README.md` 与同目录 `CONTRACT.md` |
| 验证与构建 | `tools/check.py`、`tools/build.py`、`tools/performance.py` |

`project.godot` 和 `main.tscn` 留在根目录，Godot 可以直接打开。正常开发无需进入历史工具或查阅旧方案。

## 资源只有一个运行入口

当前图像由 `assets/manifest.json` 和明确的 UI/音频加载路径读取。`art_sources/` 保存来源、原始工程和加工证据，不打进游戏包。部分旧角色骨骼仍被作者工具和历史测试引用，放在 `assets/characters/rigs/`；默认 Q 版发布包不包含这些场景。

部分冻结规则 JSON 的 `asset_path` 仍是当时记录的来源路径，不能用它加载当前图像，也不能批量改写。当前图像路径查询使用 visual_skin/manifest。这里保留原文是为了兼容已有目录摘要和存档，并非同时维护两套素材。

`assets/generated/` 是游戏需要直接读取的轮廓缓存与构图数据，属于源码资产；`.godot/` 是引擎可重建的导入缓存，不入库。调整图片或清单后使用 `tools/assets/` 生成器更新对应缓存。

## 测试与输出分开

- `tests/regression/`：行为回归；执行列表和超时在 `tests/suites.json`，不靠扫描文件名猜测当前套件。
- `tests/fixtures/`：历史输入、快照和少量测试适配器。不能重录以掩盖回归。
- `tests/visual/`、`tests/scenarios/`：画面、性能和操作场景。
- `build/qa/`：可重新生成的测试结果；`build/`、`.local/` 均不入库。
- `tools/legacy/`：历史加工工具，不作为当前入口，不自动执行。旧工具可能依赖当时的文件与环境。

本机历史设计与运维资料归档在 `.local/history-docs/`，未作为“确定无用”删除，也不随源码分发。根目录规范维护当前规则，完整旧规范保存在 `docs/development/history.md`、`docs/design/history.md`。

## 发布与兼容

`data/runtime-files.json` 是明确的运行文件清单，由 `python3 tools/assets/runtime_manifest.py` 生成；构建只复制清单列出的文件，再执行 Godot 导出。新增动态加载目录时需同时更新生成器和清单，不能依赖整个 assets 目录被偶然打包。

路径变更不应该使现有玩家进入不同的在线匹配池。`tools/maintenance/layout-map.json` 记录本次原路径与最终路径；`tools/release_manifest.py` 先将源码中的路径拼写还原为发布时的拼写，再计算既有摘要。真正的规则代码/数据变化仍会改变摘要。此处理仅在开发验证阶段使用，游戏运行不依赖这份映射。

版本化战斗继承链、历史校验器和 `data/compat/` 仍是现行兼容依赖。本轮保留原调用关系。日后若要减少继承层次，应作为独立行为重构，沿用冻结战斗和存档案例验证，不能在目录搬迁中顺手改写。

## 验证记录

在独立的干净源码目录导入并验证，未使用原工程目录补充文件：

| 验证 | 结果 |
| --- | --- |
| 当前登记游戏回归 | 155 / 155 组通过 |
| 凭证服务单元测试 | 68 / 68 项通过，无跳过 |
| 客户端与本地凭证服务联调 | 23 项检查通过；使用测试专用 OSS 替身，不是云端重验 |
| 图片、音频、字体、轮廓二进制比对 | 1,293 个文件原字节不变 |
| 冻结规则与夹具 JSON 独立复核 | 46 份字节不变 |
| 当前素材清单、轮廓缓存与保留骨骼场景 | 结构专项通过，四方向缓存可读取 |
| 规则摘要与池身份 | 保持发布基线；验证真实规则文本变更仍会改变摘要 |
| 运行包 | 901 项显式资源，PCK 1,069,805,060 字节；源码目录外启动、图像/音频解码、角色/物品路径与标题场景检查通过 |

PCK 检查沿用原图读取方式：Godot 会提示建议使用导入图片资源；包内保留原文件的实际解码断言已通过。退出测试时仍报告 4 个 ObjectDB 实例未释放，未在这次目录迁移中顺便改写既有资源生命周期。该检查不等于 Windows/macOS/Web 三端安装包已验收。

同一台 Mac、Godot 4.7.2、隐藏原生窗口，使用心第 10 回合双方 15/22 件物品的冻结案例：

| 指标 | 整理前 | 整理后 |
| --- | ---: | ---: |
| 绘制平均耗时 | 7.51 ms | 7.13 ms |
| 绘制 P95 | 10.20 ms | 9.05 ms |
| 绘制峰值 | 45.52 ms | 34.43 ms |
| 帧等待 P95 | 23.07 ms | 22.62 ms |
| 平均绘制调用 | 1,147 | 1,147 |

这是单次同案例回归，数值差异不作为性能优化收益；绘制工作量一致，未发现因目录迁移导致轮廓缓存失效的回退。日志和原始测量保存在本机 `build/structure/` 与 `build/qa/`，不打进源码或游戏包。

独立审查修复了六个保留骨骼场景的旧脚本引用，以及在线测试夹具迁移后的 Python 相对导入；相应检查重新通过。

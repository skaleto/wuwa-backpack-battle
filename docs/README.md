# 文档索引

当前工作先读项目根目录的 [README](../README.md)、[AGENTS](../AGENTS.md)、[开发规范](../DEVELOPMENT.md) 和 [设计准则](../DESIGN_PRINCIPLES.md)。用户最新明确要求优先；根规范维护当前约束，版本记录负责追溯，不再把每轮修改连续追加为并列的当前规则。

| 内容 | 入口 | 使用方式 |
|---|---|---|
| 当前开发规则 | [开发规范](../DEVELOPMENT.md) | 模块边界、兼容、身份、验证与无干扰工作方式 |
| 开发规范原文 | [开发历史](development/history.md) | 2026-10-29 整理前完整归档，非当前指令 |
| 当前设计规则 | [设计准则](../DESIGN_PRINCIPLES.md) | 玩法、空间、视觉与体验验收 |
| 设计准则原文 | [设计历史](design/history.md) | 含明确被覆盖的旧规则，非当前指令 |
| 最新 Windows 试玩包 | [demo.3 发布说明](release/windows-demo3.md) | 国内下载、校验和与本轮验证范围 |
| 三端试玩包 | [三端发布说明](release/three-platform.md) | 下载运行、Web 部署与可复现导出 |
| 网页试玩部署 | [CloudBase 部署](release/cloudbase.md) | 试玩地址、发布命令、跨域与验收范围 |
| iPhone 原生预览 | [iOS 构建说明](release/ios-preview.md) | Xcode 工程、初始化阻塞与真机验收边界 |
| 发布与仓库 | [GitHub 与产物说明](release/github.md) | LFS、构建产物和发行边界 |
| 项目结构与资源边界 | [结构说明](development/structure.md) | 当前入口、运行资源、冻结输入与构建清单 |
| 简洁伙伴卡与随机货架 | [本轮改动](development/polish-140.md) | 视觉、供给版本、兼容及验证范围 |
| 招募设计 | [招募设计](design/recruitment.md) | 仍保留的功能设计依据 |

冻结目录、夹具、快照与运行所需兼容材料不是普通文案，不能因为归档或整理目录就删除、重录、批量改字段。当前归属见根 README：兼容数据位于 `data/compat/`，冻结测试位于 `tests/fixtures/`；迁移必须保留原始字节并更新消费者，不据此提前声称迁移完成。

历史文件为保持原文而保留旧路径与相对链接；按原文件所在位置解释。必要的历史引用无法访问时，应查来源和运行数据，不以猜测补写规则。截图、日志与概念图证明其记录范围内的事实，不自动成为当前版本验收。

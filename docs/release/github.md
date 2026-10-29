# GitHub 仓库与构建产物

核实日期：2026-10-29。

- Git：代码、配置样例、构建脚本和测试输入。
- Git LFS：图片、声音、字体及二进制几何数据。首次克隆需执行 `git lfs pull`；不要将 `.godot/`、本地环境、凭据或玩家存档入库。LFS按仓库所有者配额统计，历史版本也占空间。
- Releases：面向玩家分发 Windows/macOS 安装包、Web离线包、校验和及发行说明。每个附件小于 **2 GiB**；官方未设置单个Release总容量或下载带宽总限制。当前约1.0GiB的PCK可作为附件，但PCK本身不是独立可执行游戏。
- Actions artifacts：用于构建过程和短期验收，受套餐存储配额和保留期限约束；不应作为长期下载站。
- Pages：适合下载介绍页。发布网站大小上限 **1GB**，当前 PCK 已接近这一量级，且不等同于 Web 导出结果，不能直接当作网页发布。网页版还需压缩/拆包、浏览器性能测试及身份/OSS的精确跨域来源配置。

推荐流程：代码提交 → 运行回归 → 导出并验收目标平台 → 为确切提交打版本标签 → 发布GitHub预发行版并附安装包、SHA256和说明。当前只初始化源码仓库，不自动创建公开Release，也不将未验收PCK标为正式版本。

官方资料：

- [Releases 容量限制](https://docs.github.com/en/repositories/releasing-projects-on-github/about-releases)
- [Git LFS 计费与配额](https://docs.github.com/en/billing/concepts/product-billing/git-lfs)
- [Pages 限制](https://docs.github.com/en/pages/getting-started-with-github-pages/github-pages-limits)
- [套餐内产品用量](https://docs.github.com/en/billing/reference/product-usage-included)

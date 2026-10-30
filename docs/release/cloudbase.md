# CloudBase 网页试玩部署

2026-10-30 部署压缩后的 Web 包，游戏代码与在线规则保持不变。

试玩地址：https://clear-raccoon-d2gqs87oabfed2a47-1302322545.tcloudbaseapp.com/

## 环境与发布

- 环境：`clear-raccoon-d2gqs87oabfed2a47`，上海。
- 使用现有体验版；本次未购买套餐、开启自动续费或超额计费。控制台显示体验到期时间为 2027-04-29 23:59:59，后续以控制台为准。
- 上传目录：`build/web-optimization/web/`，12 个文件。ZIP 495.24 MiB；浏览器入口资源合计 588.62 MiB，首次加载仍较大。
- 保留环境已有的 `__auth/` 和 `cloud-admin/` 文件。

使用已授权的 CloudBase CLI 3.8.10：

```bash
tcb hosting deploy build/web-optimization/web \
  -e clear-raccoon-d2gqs87oabfed2a47 \
  --concurrency 3 --retry-count 3 --verify --entry index.html --json
```

不要额外传 `/` 作为 cloudPath；本次该写法导致 CLI 校验查找带前导斜线的对象键而误报缺失。不传 cloudPath 的部署已返回 12/12 成功、`verified: true`。

默认域名仅用于本轮试玩。腾讯会显示第三方访问提示，需要点击“确定访问”；它不是正式自定义域名，存在默认域名访问限制。正式对外推广前应配置自定义域名，并重新核对套餐、备案和流量额度。参考：[官方默认域名说明](https://docs.cloudbase.net/service/alias)。

## 在线跨域配置

CloudBase 只托管公开前端；原 ECS 凭证服务和私有 OSS 阵容桶继续使用。长期云密钥未放入 Web 包。

- 凭证服务 `PVP_CORS_ORIGINS` 在保留原站点的基础上加入上述 CloudBase origin。
- OSS 新增该精确 origin 的规则：GET、POST、HEAD；允许头 `content-type`；暴露头 `ETag`；缓存 600 秒。原站点规则保留，桶仍私有。
- 服务端修改前备份配置、代码及一致性 SQLite，并验证备份数据库可恢复。备份标识：`cloudbase-20261030T015504Z`。

回滚仅移除新增 origin 或恢复原配置并重启凭证服务；本次没有修改数据库结构，不应为回滚 CORS 覆盖后续真实玩家数据。静态托管无本次部署的自动版本回滚，后续更新前保留上次部署包；回退时重新上传该包。

## 本次验证范围

- CLI 上传校验：12/12，通过。
- Chrome 实际加载主界面、整备及完整人机战斗结算。
- 在线模式完成匹配流程和战斗结算，画面明确显示“练习对手补位”；尚未验证真人阵容匹配。
- 新 origin 的凭证服务预检 204、OSS 预检 200；实际运行服务凭据读取 OSS 列表和最近上传对象 HEAD 均为 200。
- 修正跨域后浏览器验收阶段未出现新的网络错误。
- 日志与实机截图位于 `build/web-optimization/cloudbase-deploy.log`、`build/web-optimization/cloudbase-online-proof.png`，不提交身份或签名票据。

本轮 GitHub Releases 上传按用户要求暂停。网页成功部署不代表压缩包已更新到 GitHub。

## Windows 国内下载备用入口

2026-10-30 为无法访问 GitHub 的 Windows 电脑镜像现有 `v0.1.0-demo.1` 安装包，没有重新编译或修改包内容。

- [Windows x86_64 ZIP](https://clear-raccoon-d2gqs87oabfed2a47-1302322545.tcloudbaseapp.com/downloads/windows/SolarisBrawl-v0.1.0-demo.1-Windows-x86_64.zip)：894,911,683 字节，约 853 MiB。
- [SHA256SUMS.txt](https://clear-raccoon-d2gqs87oabfed2a47-1302322545.tcloudbaseapp.com/downloads/windows/SHA256SUMS.txt)。ZIP SHA-256：`1ae4c49fcd70a68fea473d1ef034e8d8077092f1b1869f4b985e6abed96ae57c`。
- 上传到独立 `downloads/windows` 前缀，未覆盖网页入口；CLI 校验 2/2 成功。
- 完整解压后运行 `SolarisBrawl.exe`，保留同目录 `SolarisBrawl.pck`。无需 Godot，也不从 GitHub 拉取运行资源。
- 同样属于 CloudBase 测试域名，可能显示访问提示；本次仅提供备用下载，不承诺不同地区的下载速度。

## 最新 Windows 下载（demo.3）

[新版 Windows ZIP](https://clear-raccoon-d2gqs87oabfed2a47-1302322545.tcloudbaseapp.com/downloads/windows/v0.1.0-demo.3/SolarisBrawl-v0.1.0-demo.3-Windows-x86_64.zip)，897935685 字节。SHA-256：`c2b6f79fc76b3568755fd461fddb403daeb37916eb897060613d44711184b387`。使用独立版本前缀，不覆盖旧安装包或网页入口。本轮只更新 Windows 下载，不更新站点内的旧 Web 游戏。

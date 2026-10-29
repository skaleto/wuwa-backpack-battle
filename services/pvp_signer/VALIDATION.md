# 本地验证记录 — 2026-10-28

本记录描述部署前本地验证。后续已授权的 ECS 部署、真实 OSS 检查和精确清理见 [部署报告](../../docs/pvp-v134/deployment.md)。

## TDD 观察

1. 首先新增 26 项业务测试；运行 `python3 -m unittest discover -s services/pvp_signer/tests`，观察 26 个 assertion failure：凭证服务模块缺失。实现业务层后同命令 26/26 通过。
2. 新增 8 项 HTTP 和 6 项 OSS 适配测试；安装官方 `oss2==2.19.1`，运行本目录 `.venv/bin/python -m unittest discover -s services/pvp_signer/tests`，观察 14 个 assertion failure：HTTP/OSS 适配缺失。实现后 40/40 通过。
3. 新增 2 项管理 CLI 测试；先观察 2 个 assertion failure：manage.py 缺失。实现后 42/42 通过。

## 最终运行

宿主 macOS ARM64。Python 3.12.14（本目录独立 runtime/venv），完整锁定依赖；没有任何真实云凭据或云网络操作。

```sh
services/pvp_signer/.venv312/bin/python -m unittest discover -s services/pvp_signer/tests -v
```

首次结果：`Ran 42 tests in 5.281s — OK`，0 skipped。关闭竞态修复后最终结果：`Ran 43 tests in 1.213s — OK`，0 skipped。业务 26、HTTP 9、真实 SDK 离线签名 6、CLI 2。生产模块 compileall 通过。

SDK 2.19.1 首次导入在 Python 3.12 报其自身 docstring `invalid escape sequence` SyntaxWarning，签名运行报其 `datetime.utcnow()` DeprecationWarning。测试未屏蔽这些上游警告；没有失败项。Python 3.14.7 同样 42/42 通过。

另外实际启动 main.py 独立子进程，只传入临时数据库、随机回环端口和测试 pool 配置，实测：

- GET /healthz → 200 / unconfigured。
- 邀请码激活和相同 request_id 重试 → 相同 player_id/token。
- 有效 Bearer 的 read-ticket → 503 / storage_unconfigured。
- 标准错误日志未包含邀请码或 token。
- SIGTERM 正常关闭，退出码 0。

以上数据库、端口和进程均隔离并清理；未读用户密钥、未 SSH、未部署、未提交父仓库。

## 部署前未验证项（后续结果见部署报告）

真实 OSS POST、重复键禁止覆盖、下载、真实 XML 分页、过期、query 篡改拒绝、RAM 删除/ACL 限制；专用桶从未启用 versioning 的事实；ECS Linux 上依赖安装、systemd/Nginx 配置加载、真实 TLS/IP 代理与资源上限。模板是部署输入，不能当作云端验收记录。

## 独立审查修复：关闭时等待在途请求

审查指出 `daemon_threads=True` 让 server_close 不等待已接受请求，随后关闭 SQLite 会让在途 /sessions 失败。先添加暂停真实 HTTP 激活请求的回归测试，复现 `SQLite closed while an accepted /sessions request was paused`，当时 9 个 HTTP 测试中 1 项失败。

最小修复使用标准库 ThreadingMixIn 的退出机制：`daemon_threads=False`、`block_on_close=True`。停止接收请求后，server_close 等待请求 worker 完成，再关闭 SQLite。回归检查暂停期间数据库不关闭、释放请求后仍返回 200、最终数据库关闭。Python 3.12 全量 43/43 通过。

实际 main.py 子进程另用未发送完正文的已接受请求进行 SIGTERM 验证：socket 的 10 秒空闲超时结束请求，关闭耗时 **9.91 秒**、退出码 0、无 request_failed，低于 systemd 配置的 15 秒硬停止上限。10 秒是 socket 空闲超时，并非恶意持续滴流请求的总时长；异常阻塞仍由 systemd 15 秒上限终止，正常路径始终先排空请求再关闭数据库。

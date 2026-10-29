# 异步阵容池凭证服务（V138）

独立 Python 3.12 标准库 HTTP + SQLite 服务。ECS 只签发身份和短期 OSS 凭据；阵容直接上传 OSS，匹配、验摘要、模拟和结算均在客户端。没有权威战斗服务，没有接收阵容或代传文件的接口。

## 运行与验证

```sh
python3.12 -m venv services/pvp_signer/.venv
services/pvp_signer/.venv/bin/python -m pip install -r services/pvp_signer/requirements.txt
services/pvp_signer/.venv/bin/python -m unittest discover -s services/pvp_signer/tests -v
```

`requirements.txt` 锁定 `oss2==2.19.1` 及完整传递依赖。业务测试不依赖 SDK；没有安装 SDK 时签名测试会明确 skip，不能把 skip 视为签名通过。测试中的 fake signer 只位于 tests，生产入口没有 fake 开关。测试使用自动清理的独立 SQLite 与回环随机端口，不访问云资源。

## 接口

所有 JSON 响应 `Cache-Control: no-store`。错误为 `{"error":"code"}`，状态码 400 输入无效、401 凭据失效、409 邀请已消费或冻结上传冲突、413 正文过大、415 非 JSON、429 限额、503 存储未配置或服务不可用。

| 接口 | 请求 | 响应 |
| --- | --- | --- |
| POST /sessions | `{invite, request_id?}` | `{player_id, token}` |
| POST /devices/session | `{installation_id, secret}`，迁移时可附有效旧 Bearer | `{player_id,token,expires_at}` |
| GET /config | 无 | `{protocol:1,pool_ids:[...],max_bytes:262144}` |
| POST /storage/upload-ticket | Bearer + `{pool_id,round,wins,losses,run_id,sha256,size}` | `{key,url,fields,expires_at}` |
| POST /storage/read-ticket | Bearer + `{pool_id,round,key?,continuation?,start_after?,wins?}` | `{url,expires_at}` |
| GET /healthz | 无 | `{status:"configured"或"unconfigured",protocol:1}` |

`expires_at` 为 Unix UTC 秒。`configured` 只说明本地签名配置完整，不代表云端连接或 RAM 策略验证通过。未提供密钥、区域、桶名或版本控制前置声明时，健康接口仍可读，所有授权后的存储请求返回 503；绝不输出模拟 OSS 票据。

V138 默认客户端使用匿名设备会话：首次联网前私密持久化随机 installation_id（小写 hex 32 位）和 secret（小写 hex 64 位）。同设备重试返回相同有效 token；到期以相同 secret 静默续期并保留 player_id，默认有效期 1 天。SQLite 仅存 secret/token 摘要，撤销玩家不能续期复活。首次绑定可携有效旧 Bearer，过期或无效旧身份不得自动换成新玩家；绑定后旧邀请恢复返回 409 `device_already_bound`，日常续期不附 Authorization。完整契约、失败码、迁移恢复与配额见 [V138 服务契约](CONTRACT.md)。

客户端首次激活前持久化随机 `request_id`（32–128 位 `[A-Za-z0-9_-]`，推荐 32 字节安全随机 URL-safe 编码）。同邀请码与同 request_id 恢复完全相同身份及令牌，不延长到期时间；换 request_id 返回 409。未提供 request_id 的旧接口调用仍兼容，但丢失响应后无法恢复。存储成功后删除本地邀请与 request_id，只保留 player_id/token；恢复材料与 token 都不能写日志。邀请码由管理端生成至少 256 位熵。SQLite 只保存邀请、request_id、token 的 SHA256 摘要；恢复 token 由原始邀请作为密钥 HMAC 派生，服务不保存可恢复的明文凭据。

默认邀请码 7 天内可首次激活；token 30 天失效，可本地撤销。已激活邀请过了初始激活期限，只要 token 仍有效，仍允许同请求恢复。撤销身份立即阻止新的票据；已签发的 OSS 票据最多仍有效 5 分钟。

## 上传与读取边界

pool_id 必须在环境白名单；round 为 1–32；wins/losses 非负且总和为 round−1；run_id 为 1–64 位 `[A-Za-z0-9_-]`；sha256 为精确 64 位 hex，归一小写；size 为 1–262144 的整数。HTTP 票据请求正文上限 16 KiB，拒绝重复 JSON 字段、非有限数值、chunked、额外业务字段。

服务构造完整对象键：

```text
test/pools/{pool_id}/round/{RR}/wins/{WW}/{player_id}/{run_id}-{sha256}.json
```

同 player_id/run_id/round 的 metadata 与 key 在 SQLite 事务中冻结，包括 pool_id、战绩、hash、size。相同参数允许续签，任何改变返回 409，跨 pool 也不能另开同回合授权。授权记录先提交，再生成票据；签名失败也不会允许改变冻结阵容。

客户端使用 multipart POST：将 `fields` 所有字段原样加入表单，文件字段名 `file`，文件必须放最后，文件 part 的 Content-Type 为 application/json。**HTTP 请求本身 Content-Type 是 multipart/form-data 带 boundary**。签名 policy 有效 300 秒，绑定桶名、完整 key、精确字节大小（最小值=最大值=size）、private ACL、Content-Type、x-oss-content-type、x-oss-forbid-overwrite=true、成功状态 201 和 V4 参数。`x-oss-content-type` 防止 file part MIME 覆盖对象类型。

客户端不能把 POST policy 当 PUT URL 使用。下载和列举票据用 GET，无需额外签名 headers；不可自行增删 URL query。列表固定本池本回合 prefix、list-type=2、max-keys=100、encoding-type=url；continuation 是不透明分页令牌，start_after 必须在相同前缀，二者不能同时给出。key 下载仅允许该回合的规范对象路径（可读取其他玩家，用于匹配）。XML 的 URL 编码键由客户端按 encoding-type 解码一次。

服务没有接触文件字节，sha256 是客户端声明；OSS POST policy 不验证该 SHA256，下载端必须自行核验准确字节摘要、schema、完整版本、身份及战绩。它也不证明客户端战绩真实。该边界符合简易异步 MVP。

列表可选 `wins`（整数 0..round−1），将签名 prefix 收窄为上述对象目录的 `/wins/WW/`；start_after 也必须在所选完整 prefix 内，可使用不存在的随机 owner 前缀作起点。wins 与 key 互斥；下载 key 仍沿用原校验。省略 wins 保留整回合列表。

配额是持久化 UTC 整点小时窗口，默认每身份 600 次票据、每 IP 1800 次票据、每 IP 30 次激活尝试；失败认证也计入 IP 次数，相同票据续签同样计数。旧窗口记录自动清理。SQLite 保存哈希 IP，不保留原始 IP。服务有 16 并发连接上限与 10 秒 socket 空闲超时；生产必须通过缓冲正文的 TLS 反向代理。关闭时先停止接收，等待已接受的请求结束，再关闭 SQLite；systemd 保留 15 秒硬停止上限处理异常阻塞。

匿名设备会话与邀请共享每 IP 激活额度；另有每安装每小时 30 次额度，错误 secret 也计数。`PVP_DEVICE_TOKEN_TTL` 默认 86400，`PVP_DEVICE_HOUR_LIMIT` 默认 30。`PVP_CORS_ORIGINS` 默认空，仅可配置逗号分隔的精确 HTTP(S) Origin，无通配符、路径或尾斜杠；配置来源才能发起带 Origin 请求。OPTIONS 只允许各已知接口实际 GET/POST 方法及 Authorization、Content-Type 请求头，不启用 cookie credential CORS。原生无 Origin 请求兼容。OSS 桶浏览器 CORS 仍需独立配置。

## 官方签名适配

GET 使用官方 oss2 AuthV4。`Bucket.sign_url` 在 2.19.1 中拒绝空 key，故 ListObjectsV2 通过官方 `oss2.http.Request` + `AuthV4._sign_url` 对桶根路径签名。这是固定版本的内部方法适配，升级 SDK 必须重新跑测试；测试在固定时间下改变 prefix/max-keys/list-type/encoding-type/continuation/start-after，验证签名变化，不发网络请求。

oss2 没有公开 POST-policy 签名 API；POST 按官方 V4 policy 文档用 Python 标准库 HMAC-SHA256 实现，有政策字段和独立派生计算测试。

参考：[官方 SDK auth.py](https://github.com/aliyun/aliyun-oss-python-sdk/blob/master/oss2/auth.py)、[SDK api.py](https://github.com/aliyun/aliyun-oss-python-sdk/blob/master/oss2/api.py)、[POST V4 签名](https://help.aliyun.com/zh/oss/developer-reference/signature-version-4-recommend)、[PostObject](https://www.alibabacloud.com/help/en/oss/developer-reference/postobject)、[ListObjectsV2](https://www.alibabacloud.com/help/en/oss/developer-reference/listobjectsv2)。

## 独立部署模板

1. 创建专用私有 OSS 桶；**必须从未启用 versioning**。Enabled 或曾启用后 Suspended 都会使 forbid-overwrite 无效。上线后禁止改变版本控制；私有桶、公共访问阻断、生命周期清理策略由云管理员单独配置。
2. 专用 RAM 用户/角色只服务本桶 `test/pools/*`，不要复用其他业务密钥。`deploy/ram-policy.json` 是待替换桶名、待云端验收的最小权限模板；不授予删除、改对象/桶 ACL、改版本控制权限。返回客户端的只是不可修改的 POST policy/GET URL，不是 AccessKeySecret 或可任意操作的 STS 凭据。
3. 将此目录复制到 `/opt/pvp-signer`，Python 3.12 venv 安装 requirements。创建无登录 `pvp-signer` 系统用户。代码 root 拥有、服务用户只读。SQLite 在独立 `/var/lib/pvp-signer`；不要覆盖其他服务、数据库、用户游戏存档。
4. 将 env 示例复制为 `/etc/pvp-signer/pvp-signer.env`，root:root / 0600，通过受控方式填入密钥；**不要把秘密放进 shell 历史、参数、仓库或报告**。填写当前客户端确切 pool_id；确认桶前置条件后填 `PVP_OSS_VERSIONING=never-enabled`。systemd 读取独立环境文件，程序不会寻找或读取其他项目配置。
5. 安装 `deploy/pvp-signer.service`；StateDirectory/LogsDirectory 由 systemd 管理。监听仅 127.0.0.1:8430；192 MiB 内存、25% CPU、32 tasks、256 fd 上限。业务日志自身轮转，单文件 2 MiB、保留 3 个旧文件（约 8 MiB 上限）；SDK 日志禁用，不记录 token、邀请、签名URL、正文或原始请求路径。
6. 备份已有 Nginx 配置后，把独立 location 模板纳入现有 HTTPS server；`nginx -t` 成功后才 reload。`PVP_TRUST_PROXY=1` 只用于该受信回环代理，它必须覆盖 `X-Pvp-Client-IP` 为真实 remote_addr。不要直接信任客户端 X-Forwarded-For。若本地直接调试，设为 0。如再加 CDN，需要先正确配置 Nginx real_ip 信任范围。

本地管理（使用服务用户，避免产生错误文件所有权）：

```sh
sudo -u pvp-signer /opt/pvp-signer/.venv/bin/python /opt/pvp-signer/manage.py create-invite
sudo -u pvp-signer /opt/pvp-signer/.venv/bin/python /opt/pvp-signer/manage.py list-invites
sudo -u pvp-signer /opt/pvp-signer/.venv/bin/python /opt/pvp-signer/manage.py revoke-invite INVITE_HASH
sudo -u pvp-signer /opt/pvp-signer/.venv/bin/python /opt/pvp-signer/manage.py revoke-player PLAYER_ID
```

create-invite 只向当前 stdout 返回一次明文邀请码；不要收集到服务日志。list-invites 只列摘要、有效期、身份及撤销状态。revoke-invite 阻止邀请码激活/恢复；撤销已激活令牌要执行 revoke-player。

## 上线前仍需验证

2026-10-28 已按用户授权部署并完成真实 OSS 验证，实际范围、共享服务器密钥的权限边界、26 项 HTTP 检查及精确清理记录保留在本机私有运维归档中，不随源码分发。下列清单保留用于后续独立部署的验收：两个身份直传和交叉读取、同键再次上传拒绝、改key/大小/ACL/forbid-overwrite被拒绝、修改List query被拒绝、第一页和真实分页、GET、5分钟过期、删除与改ACL权限被拒绝、数据库重启恢复、TLS/IP代理和资源限制。RAM模板与POST ACL字段的实际组合也必须由真实桶验收，不能仅凭离线 policy 正确就宣称上线安全。

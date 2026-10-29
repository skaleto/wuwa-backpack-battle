# V138 凭证服务接入契约

客户端在首次联网前用安全随机源生成 `installation_id`（16 随机字节、小写 hex 32 位）及 `secret`（32 随机字节、小写 hex 64 位），先原子私密保存，再发请求。重试、更新及续期必须复用它们；网络失败、401 或 429 不能自行重新生成身份。客户端不需要用户注册，也不持有云 AccessKeySecret。

## 匿名会话

`POST /devices/session`，`Content-Type: application/json`：

```json
{"installation_id":"0123456789abcdef0123456789abcdef","secret":"0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef"}
```

上面的示例仅展示格式，不能充当实际随机凭据。成功响应包含且仅包含 `player_id`（32 位小写 hex）、`token`（64 位小写 hex）、`expires_at`（Unix UTC 整数秒）。新设备自动创建；同设备同 secret 在当前 token 有效期间原样恢复相同 token/到期时间，包含响应丢失和服务重启。到期时重发同一请求续期，player_id 不变，token 变化；默认有效期 86400 秒。存储接口使用 `Authorization: Bearer <token>`。

设备已绑定后，日常续期省略 Authorization。撤销 player 后不能用设备 secret 复活。非法格式 400；secret 错误、无效 bearer、过期 bearer 或已撤销 player 为 401 `unauthorized`，失败不创建新玩家。IP/设备额度为 429 `quota_exceeded`，客户端应退避，保留本地身份，不循环刷接口。

SQLite 仅保存设备 secret 的 SHA256、token 的 SHA256；token 由客户端 secret 和 installation/player/expiry 作 HMAC-SHA256 确定性派生。服务端不需要新增长期签名密钥，不保存可恢复的设备 secret 或 bearer。

## 已有邀请身份迁移

第一次设备请求可附当前**仍有效且未撤销**的旧 `Authorization: Bearer <token>`，将安装绑定到同一 player_id；保留既有上传记录与冻结 key。绑定立即换成设备 token，旧 bearer 不再签发存储票据。客户端原子保存新响应后删除迁移标记，此后不带旧 Authorization。

绑定响应丢失时，同 installation + secret + 原始旧 bearer 可重试，直到旧 bearer 的原始到期时刻；服务仅保存该旧 bearer 的摘要与原始期限。原始期限过后同设备仍能不带 Authorization 续期。未知/过期/撤销旧 bearer 不能发起绑定，也不会回落为新玩家；本地旧身份应保留并显示恢复错误。已经绑定的玩家拒绝第二安装绑定，409 `device_already_bound`。只有有效的当前 token 可用于检查第二安装绑定冲突。

未迁移的 `/sessions` 邀请接口维持原有请求和响应，原 token 默认 30 天，与设备 1 天 TTL 独立。已迁移 player 的旧邀请恢复返回 409 `device_already_bound`，避免成功返回已经失效的旧 token。

## 胜场分层列表

`POST /storage/read-ticket` 的列表请求增加可选 `wins` 整数，范围 `0..round-1`。例如 `{pool_id,round:2,wins:1}` 签发的 ListObjectsV2 精确 prefix 是 `test/pools/{pool_id}/round/02/wins/01/`，依旧最多 100 项。省略 wins 保留原本整回合列表接口。

`start_after` 必须以当前选择的完整 prefix 开头，可在其后接随机 32 位 owner hex，不要求恰好存在对象；禁止百分号或 `..`。`continuation` 为不透明 OSS 分页 token；与 start_after 互斥。wins 仅用于列表，不能和 key 同传；下载仍用 `{pool_id,round,key}` 并执行原规范 key 校验。

## 浏览器来源与部署

`PVP_CORS_ORIGINS` 是逗号分隔的精确 HTTP(S) Origin，例如 `https://play.example.com`；默认空表示不接受带 Origin 的跨来源请求。拒绝 `*`、域名通配符、`null`、路径、尾斜杠及用户信息。原生无 Origin 请求照常工作。

允许来源的实际成功与错误响应携带该精确 `Access-Control-Allow-Origin`、`Vary: Origin`，不启用 cookie credential CORS。OPTIONS 仅放行已知路径及其实际 GET/POST 方法，允许请求头仅 Authorization、Content-Type，成功 204 空体。拒绝来源 403，且在会话/上传授权等业务变更之前拦截。反代应透传 OPTIONS/Origin；现有 nginx location 模板已经透传全部方法。OSS 的直传/读取浏览器 CORS 属于桶配置，不能由本服务 CORS 替代。

新增环境配置：

| 配置 | 默认 | 含义 |
| --- | --- | --- |
| PVP_DEVICE_TOKEN_TTL | 86400 | 设备 token 有效秒数，正整数 |
| PVP_DEVICE_HOUR_LIMIT | 30 | 每安装 ID 每小时尝试数，包含错误 secret |
| PVP_CORS_ORIGINS | 空 | 精确 Origin 白名单 |

沿用 `PVP_SESSION_HOUR_LIMIT=30`，邀请激活与设备会话共享每 IP 每小时额度；错误认证/格式也计 IP 额度。有效 installation_id 的错误 secret 也计设备额度。配额以持久化 UTC 整点小时窗口计数，跨连接/重启生效。此为有界 MVP 防滥用，不声称防止分布式多 IP 注册。

数据库变更只新增 `devices` 表与玩家唯一绑定，不改已有 players/invites/uploads 结构。升级前正常备份数据库；本次本地验证使用临时独立数据库，无生产数据访问。

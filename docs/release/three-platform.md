# 三端试玩包（v0.1.0-demo.1 / V138）

这是同一套玩法与规则的 Windows、macOS、Web 试玩导出。发布为 GitHub Pre-release，产物不提交 Git，只作为 Release 附件。

## 下载后运行

| 包 | 内容与启动方式 |
| --- | --- |
| `SolarisBrawl-v0.1.0-demo.1-Windows-x86_64.zip` | 完整解压到文件夹，运行 `SolarisBrawl.exe`；同目录 `.pck` 不能删除或拆开。无需安装 Godot。 |
| `SolarisBrawl-v0.1.0-demo.1-macOS-universal.zip` | 解压后运行 `SolarisBrawl.app`，可移动到 Applications。包含 Apple Silicon 和 Intel 架构；无需安装 Godot。 |
| `SolarisBrawl-v0.1.0-demo.1-Web.zip` | 静态网站部署包，不是双击打开的网页。完整解压后通过 HTTP(S) 服务访问 `index.html`。 |

桌面包没有开发者证书签名与公证。macOS 包使用本地 ad-hoc 签名，首次下载可能被 Gatekeeper 拦截；确认来自本仓库且校验和一致后，可按系统“隐私与安全性”里的“仍要打开”流程操作。Windows 包没有 Authenticode 签名，可能出现未知发布者提示。本版不要求关闭系统安全防护。

`SHA256SUMS.txt` 对应三个压缩包；macOS/Linux 可运行 `shasum -a 256 -c SHA256SUMS.txt`（需先下载其中列出的所有包）。Windows 可用 PowerShell `Get-FileHash 文件名 -Algorithm SHA256` 对照。

## Web 本地运行与部署

本地试玩：在解压后的目录执行 `python3 -m http.server 8000 --bind 127.0.0.1`，浏览器打开 `http://127.0.0.1:8000/`。浏览器应支持 WebAssembly 与 WebGL 2.0。不要用 `file://` 打开 HTML，也不要单独改名某个 `index.*` 文件。

公网部署：上传整个目录，入口为 `index.html`，启用 HTTPS；`.wasm` 使用 `application/wasm`，`.pck` 使用 `application/octet-stream`。这是单线程 Web 导出，不依赖多线程版的跨源隔离要求。可部署至独立 OSS 资源桶与 CDN，不与玩家阵容数据桶混用。对大文件启用合适的缓存/传输压缩，并保证新 HTML 与资源来自同一版本。

人机模式可独立运行。在线模式还需要为最终网站的精确 Origin 配置凭证服务 `PVP_CORS_ORIGINS` 和 OSS 的对应跨域规则；本地试玩地址默认不在生产白名单中。不要为了让测试通过开放所有来源，不要把云 AccessKey 放进网页。部署域名尚未确定，所以本次不修改生产 CORS 白名单，也不宣称 Web 生产在线对战已经验收。

当前 Web PCK 约 1 GiB，首次下载较大；此版保留完整素材，尚未做 Web 专项减包与移动端性能适配。浏览器数据属于网站来源，换域名、清除站点数据或使用隐私窗口会影响本地存档与安装身份的保留。

## 构建

1. 安装 Godot 4.7.2 的匹配官方导出模板，核对官方 SHA-512；Windows 使用 x86_64 Release 模板，macOS 使用 universal 模板，Web 使用 `web_nothreads_release.zip`。
2. 在源码目录执行 `python3 tools/release_manifest.py --check`，并运行必要回归。
3. 执行 `python3 tools/build.py --stage /abs/new-runtime`，生成全新运行资源暂存目录及清单；不要直接导出包含作者素材与测试夹具的整个工作目录。
4. 用 Godot 导入暂存目录，再依次导出：

```sh
godot --headless --path /abs/new-runtime --editor --import
godot --headless --path /abs/new-runtime --export-release Windows /abs/output/windows/SolarisBrawl.exe
godot --headless --path /abs/new-runtime --export-release macOS /abs/output/macos/SolarisBrawl.app
godot --headless --path /abs/new-runtime --export-release Web /abs/output/web/index.html
```

提前创建输出目录。Mac universal 所需的 `rendering/textures/vram_compression/import_etc2_astc` 已在工程启用；不改变玩法规则或在线池摘要。

5. 每个平台包附本说明和 `CREDITS.md`。macOS 应在完成导出签名后归档整个 `.app`，保留可执行权限。Windows 归档 exe 与 pck，Web 归档所有导出文件。
6. 检查包内无服务端/凭据/玩家存档；验证 macOS 签名与启动、Web 实际页面和一场人机战斗。Windows 的文件结构/共享数据验证不能替代 Windows 真机试玩。
7. 对最终 ZIP 生成 SHA-256；提交并推送构建配置，为确切提交打标签；先上传 Draft Release，确认附件完整再发布 Pre-release。

每版的实际验证结果和限制写入对应 Release 说明，不从“导出成功”推定所有设备均可运行。

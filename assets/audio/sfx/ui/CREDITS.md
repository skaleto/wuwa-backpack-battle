# V53 音效来源

所有正式事件音均取自现成素材，没有使用本项目的程序合成原型。下方按版本保留来源历史，当前文件级映射以 `provenance.json` 为准；当前星声见 V90，点击见 V97，胜利素材见 V98，开战及最新音量见 V99。

| 来源 | 作者 | 许可 | 使用 |
|---|---|---|---|
| [Bubble Sound Effects](https://opengameart.org/content/bubble-sound-effects) | BMacZero / Brian MacIntosh | [CC0 1.0](https://creativecommons.org/publicdomain/zero/1.0/) | 抓取、落下、受击 |
| [Interface Sounds 1.0](https://kenney.nl/assets/interface-sounds) | Kenney | [CC0 1.0](https://creativecommons.org/publicdomain/zero/1.0/) | 点选、旋转、购买、开战、攻击、治疗、合成、无效回落 |

来源原文件保存在 `sources/`；文件级 SHA-256、事件映射、输出音量与处理参数见 `provenance.json`。抓取气泡类声音并不意味着原作者将其称为“果冻”；这是一套为当前游戏选配的试听版本。

处理：统一为 48 kHz 单声道 PCM16、裁去前后静音、3 ms 边缘淡化、40 Hz 高通和 6.5 kHz 低通、音量匹配且峰值不超过 -6 dBFS。保留原音高、速度和主体声音，不使用振荡器重新生成、不拼接新旋律。可复现工具：`tools/prepare_existing_sfx_v53.py`。

采集日期：2026-10-12。公开页面标注的 CC0 与 Kenney 包内许可均已核对。

## V55 事件分工

不改原文件：轻武器攻击沿用 attack，重武器攻击复用 turn 的低沉 bong 音，音感仪/声骸攻击复用 pick 的气泡音；重武器命中复用 drop。全部保持原音高与速度，仍按 attack/hit 事件统一限流与战斗声部管理。重击仅比普通战斗声提高 1 dB，仍经过同一限制器。组合试听尚需玩家反馈。

## V87 新增事件音

新增 `star`（星位触发）、`win`（胜利）、`lose`（败北）三个事件音，仍取自上方两套 CC0 素材，无振荡器合成：

- `star.wav`：气泡 single1 升 14 半音成轻软"啫"，压至 160 ms、峰值 −10 dBFS。
- `win.wav`：bong 按 0/+4/+7 半音三连奏（0 / 0.11 / 0.22 s 起音）＋最后一拍叠加升 7 半音的气泡。
- `lose.wav`：bong 按 0/−2 半音两连落（0 / 0.17 s），更轻。

频带上限从 V53 的 6.5 kHz 放宽到 12 kHz（见 docs/audio-v87-review.md）。处理参数与哈希已追加进 `provenance.json`；可复现工具：`tools/prepare_star_stingers_v87.py`。

## V87b 真实乐器版（关键事件音重建）

V87 首版（变调派生）试听被否：程序化感明显。本版改为**真实乐器录音**，不做变调与合成：

| 来源 | 作者 | 许可 | 使用 |
|---|---|---|---|
| [Kalimba Two-Notes](https://opengameart.org/content/kalimba-two-notes) | — | CC0 1.0 | 购买（原样双音确认） |
| [Marimba Samples](https://freesound.org/people/sgossner/packs/15684/) | sgossner / Sam Gossner | **CC BY 4.0（须署名）** | 轻点(C5)、旋转(D6)、胜利(C5-E5-B5)、败北(E3-C3) |
| [VSCO 2 CE Glockenspiel](https://freesound.org/people/sgossner/packs/21027/) | Sam Gossner / Versilian Studios | 公有领域（VSCO 2 CE） | 星位(F#6)、胜利末拍点缀(C6) |

序列音（胜利/败北）由真实单音以人性化时值（±8~15 ms，种子 87）与力度渐变排成；自然混响尾保留。处理与哈希见 `provenance.json`（`revision: v87b`）；可复现工具：`tools/prepare_real_instruments_v87b.py`。原始下载件保存在 `sources/real/`。

## V89 星声去锐

历史占位音：VSCO 2 CE F#6 录音，3 kHz 高架均衡 −6 dB、6 kHz 低通、6 ms 起音与 55 ms 收尾，长 0.30 秒。已被下方 V90 用户选定素材替换，`tools/soften_star_v89.py` 仅用于复现历史版本。

## V90 用户选定：卡通气泡的第一声（2026-10-18）

- 来源：[Mixkit — Cartoon bubble pop，编号 731](https://mixkit.co/free-sound-effects/bubble/)。
- 授权：[Mixkit Sound Effects Free License](https://mixkit.co/license/modal/sfxFree/)，原件与许可快照位于 `sources/mixkit/`。该素材不是 CC0；可以用于游戏成品，不可作为独立素材包再分发。
- 用户选择 8 个试听候选中的 03，并指定只用第一声。原素材约 0.52 秒、含两下气泡；当前截取 0.000–0.250 秒，排除约 0.270 秒开始的第二下。
- 保留试听版固定增益 −8.513 dB，仅收尾 5 ms 淡出；不变调、不加混响、不重新合成。48 kHz 双声道 PCM16，播放音量仍为 −13 dB，260 ms 限流继续有效。
- 当前星声重建：`python3 tools/prepare_star_v90.py`。若重跑历史音频构建脚本，最后执行此工具恢复已选音效；不改其他事件声音。

## V95 败北与武器音

败北已替换为用户选定的 Mixkit 2876「Funny fail low tone」（试听 11），原始音色和速度保留；不再播放独立的命中／受击声。武器攻击改用各自素材，详见 [V95 署名](../audio-v95/CREDITS.md)。其他原有事件 WAV 未替换。

## V97 用户选定 25：清脆点击

- 来源：[Cartoon Pop (Clean) / unfa](https://freesound.org/people/unfa/sounds/245645/)，CC0。官方公开 HQ MP3 预览、源页与许可保存在 `sources/unfa/`。
- `click.wav` 和 `pick.wav` 均逐字节采用用户选中的 `audio-audition-sfx4-2026-10-19/single/25_click.wav`，单次约 0.172 秒。固定增益 -9.27635 dB、末尾 8 ms 淡出，48 kHz 双声道 PCM16；无变调、变速或音层叠加。
- 物品点选在按下抓取入口发出 `pick`，故按钮 `click` 与物品 `pick` 一起接入。V91 的一次手势一声规则保留，展示详情不会再发声。
- V95 声骸攻击用独立 `assets/audio-v95/echo.wav`，未随抓取声更换。星声、武器、BGM、胜败音与其他反馈保持原文件；三声递进铜管仍是项目外试听稿。

## V98 用户选定 31：连贯三声胜利铜管＋09鼓掌

- 小号录音来自 [VSCO 2 Community Edition](https://github.com/sgossner/VSCO-2-CE)，Sam Gossner / Versilian Studios，CC0。采用同一套长音录音的 A#3、D4、F4，保留原音高和速度，截短中段并以 55 ms 交叉淡化接回原录音的自然收音；起音为 0、0.225、0.475 秒。
- 鼓掌为已选 09 小群体鼓掌，源素材 Mixkit 523，使用 [Mixkit Sound Effects Free License](https://mixkit.co/license/modal/sfxFree/)。从 0.64 秒淡入，较已选鼓掌单次样本衰减 8 dB。原件、许可和精确处理参数位于 `sources/victory31/`。
- `win.wav` 与用户确认的 `audio-audition-sfx6-2026-10-20/single/31_victory.wav` 逐字节一致，3.34 秒、48 kHz 双声道 PCM16。三声铜管和鼓掌已预混成单文件，不在运行时额外叠加；既有胜利播放音量 -6 dB、事件限流和 BGM 压低保留。
- 本次仅替换胜利事件音。已选 25 点击、11 败北、V96 武器乱斗混音、V90 星声与 V94 BGM 保持原文件。

## V99 开战与结算反馈（2026-10-20）

- `start.wav` 改为逐字节复用 V97 用户选定的 25 号 Cartoon Pop (Clean) / unfa（CC0），运行音量 −7 dB。开战按钮取消额外的通用点击声；实际成功进入战斗后只播放一次开战音，鼠标与快捷键共用入口。
- `win.wav` 继续使用已批准 31 号，不改素材；运行音量从 −6 dB 提高到 −2 dB。胜败结算立即停止 BGM，不再仅降低配乐音量。
- 其他事件 WAV、武器声音及 BGM 原文件不变。当前校验见 `docs/feedback-v99/checks/asset-validation.json`。

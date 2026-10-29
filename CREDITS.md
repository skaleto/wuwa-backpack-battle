# 索拉里斯大乱斗 · 素材与许可

本作品为鸣潮题材的非官方二创试玩项目。鸣潮相关角色、武器、声骸及原作素材权利归其权利人所有；此声明不代表已获得公开发行或商业使用授权。公开发行范围仍需确认。

Godot Engine — https://godotengine.org/license/ （MIT）；完整第三方引擎许可见 https://godotengine.org/license/#third-party-components 。

下列是项目当前素材记录。生成与加工记录不替代素材权利授权。


---
来源：assets/audio/sfx/fusion-legacy/CREDITS.md

# V101 合成：聚拢与落成

只使用工程中已留存、已核对许可的真实素材。没有振荡器合成、变调、变速、铜管旋律或新的成功提示音；已认可的点击、抓取、开战、胜败、星位、武器与 BGM 文件保持原字节。

| 素材 | 作者 | 来源与许可 | 用途 |
| --- | --- | --- | --- |
| Air in a hit / 2161 | Mixkit | [来源](https://mixkit.co/free-sound-effects/swish/) · [Sound Effects Free License](https://mixkit.co/license/modal/sfxFree/) | 三次轻柔气流，从左右向中间收拢 |
| Bubble Sound Effects / single1、single2 | BMacZero / Brian MacIntosh | [来源](https://opengameart.org/content/bubble-sound-effects) · [CC0 1.0](https://creativecommons.org/publicdomain/zero/1.0/) | 材料轻响、落成后的柔软主体与余响 |
| Cartoon bubble pop / 731，仅第一声 | Mixkit | [来源](https://mixkit.co/free-sound-effects/bubble/) · [Sound Effects Free License](https://mixkit.co/license/modal/sfxFree/) | 中央的清脆落成起音 |

Mixkit 许可允许用于游戏成品，不允许作为独立素材库再分发。原件与许可证据继续留在 `assets/audio-v95/sources/`、`assets/audio-v53/sources/`；确切相对路径、原件 SHA-256、截取区间、滤波、声像、增益与输出哈希见 [provenance.json](assets/audio/sfx/fusion-legacy/provenance.json)。

运行 `python3 tools/legacy/prepare_fusion_v101.py` 可从工程内原件重建全部三个 WAV，需 ffmpeg。输出为 48 kHz 双声道 PCM16。温和低通用于控制高频，素材维持原音高和播放速度；左、右、较居中的三个轻响逐步靠向中央，气流随后汇聚。落成由中央气泡起音与较低的气泡主体叠合，不拼接乐器旋律。

- `fusion_gather.wav`：动画开始播放，1.00 秒。
- `fusion_land.wav`：动画跨过 0.94 秒、成品开始出现时播放，0.48 秒；自然动画结束不裁掉最后约 0.17 秒尾音。
- `fusion_preview.wav`：将上述两段原样置于 0.00 与 0.94 秒的 1.42 秒完整试听。它仅供用户主动播放，不由游戏或测试自动播放。

取消或跳过只停止两个合成声部；没有定时器预约后续音。新一轮合成先清理上一轮声音。无窗口 Dummy 驱动测试证明时序与取消行为；PCM 检查证明资源格式、峰值、长度及混合关系，均不代表已由人耳试听认可。


---
来源：assets/audio/sfx/fusion/CREDITS.md

# V102 短合成声

合成开始及材料靠拢保持无声。成品在 0.94 秒开始出现时，只播放一次 0.26 秒的柔和气泡；不播放 V101 的连续聚拢声或长尾。

- 素材：**Bubble Sound Effects / bubbles-single2**。
- 作者：**BMacZero / Brian MacIntosh**。
- [来源](https://opengameart.org/content/bubble-sound-effects) · [CC0 1.0](https://creativecommons.org/publicdomain/zero/1.0/)。
- 原件继续留在 `art_sources/audio/sfx/ui/bubbles-single2.wav`；原许可记录见 `assets/audio/sfx/ui/CREDITS.md`。

取原录音 0.00–0.26 秒，35 Hz 高通、3.6 kHz 温和低通、4 ms 淡入和 35 ms 淡出，固定增益匹配。48 kHz 单声道 PCM16；不变调、不变速、不叠层、不合成旋律、不增加混响。运行音量为 −7 dB，继续使用独立合成声部；取消、离开或新合成只停止该声部。

运行 `python3 tools/legacy/prepare_fusion_v102.py` 从工程保留的原件重建。确切哈希及测量见 [provenance.json](assets/audio/sfx/fusion/provenance.json)。未自动播放；技术检查不代表玩家已经确认听感。


---
来源：assets/audio/sfx/cloth/CREDITS.md

# 布袋短音效：用户确认的 01C 轻力度版

- 素材：[Poof of Smoke](https://freesound.org/people/Planman/sounds/208111/)，作者 Planman，许可 [CC0 1.0](https://creativecommons.org/publicdomain/zero/1.0/)。
- 原作者说明：用两个枕头轻碰录制。官方公开 HQ MP3 预览保存在 `sources/pillow-poof.mp3`；不是无损原件。源页许可快照见 `sources/planman-source.html`。
- 拿起 0.150 秒、放下 0.235 秒。以原 01 的温和滤波／短淡入淡出版本为基础，分别固定衰减 5dB、7dB；没有采用被否定的 01B 高频提亮，不变调变速，不叠加声音。
- 运行 WAV 与用户确认的 01C 单音逐字节一致。详细裁切、增益和校验值见 provenance.json。
- V131修正播放增益：袋声-1dB抵消现有限幅器的+1dB，保持01C试听音量，不再叠加通用UI衰减。WAV字节、音色、音高不变。
- 原 Kenney cloth／leather 素材留作历史来源，当前 bag_pick／bag_drop 已不使用；旧许可 sources/License.txt 仅对应那些历史 Kenney 文件。


---
来源：assets/audio/sfx/ui/CREDITS.md

# V53 音效来源

所有正式事件音均取自现成素材，没有使用本项目的程序合成原型。下方按版本保留来源历史，当前文件级映射以 `provenance.json` 为准；当前星声见 V90，点击见 V97，胜利素材见 V98，开战及最新音量见 V99。

| 来源 | 作者 | 许可 | 使用 |
|---|---|---|---|
| [Bubble Sound Effects](https://opengameart.org/content/bubble-sound-effects) | BMacZero / Brian MacIntosh | [CC0 1.0](https://creativecommons.org/publicdomain/zero/1.0/) | 抓取、落下、受击 |
| [Interface Sounds 1.0](https://kenney.nl/assets/interface-sounds) | Kenney | [CC0 1.0](https://creativecommons.org/publicdomain/zero/1.0/) | 点选、旋转、购买、开战、攻击、治疗、合成、无效回落 |

来源原文件保存在 `sources/`；文件级 SHA-256、事件映射、输出音量与处理参数见 `provenance.json`。抓取气泡类声音并不意味着原作者将其称为“果冻”；这是一套为当前游戏选配的试听版本。

处理：统一为 48 kHz 单声道 PCM16、裁去前后静音、3 ms 边缘淡化、40 Hz 高通和 6.5 kHz 低通、音量匹配且峰值不超过 -6 dBFS。保留原音高、速度和主体声音，不使用振荡器重新生成、不拼接新旋律。可复现工具：`tools/legacy/prepare_existing_sfx_v53.py`。

采集日期：2026-10-12。公开页面标注的 CC0 与 Kenney 包内许可均已核对。

## V55 事件分工

不改原文件：轻武器攻击沿用 attack，重武器攻击复用 turn 的低沉 bong 音，音感仪/声骸攻击复用 pick 的气泡音；重武器命中复用 drop。全部保持原音高与速度，仍按 attack/hit 事件统一限流与战斗声部管理。重击仅比普通战斗声提高 1 dB，仍经过同一限制器。组合试听尚需玩家反馈。

## V87 新增事件音

新增 `star`（星位触发）、`win`（胜利）、`lose`（败北）三个事件音，仍取自上方两套 CC0 素材，无振荡器合成：

- `star.wav`：气泡 single1 升 14 半音成轻软"啫"，压至 160 ms、峰值 −10 dBFS。
- `win.wav`：bong 按 0/+4/+7 半音三连奏（0 / 0.11 / 0.22 s 起音）＋最后一拍叠加升 7 半音的气泡。
- `lose.wav`：bong 按 0/−2 半音两连落（0 / 0.17 s），更轻。

频带上限从 V53 的 6.5 kHz 放宽到 12 kHz（见 docs/audio-v87-review.md）。处理参数与哈希已追加进 `provenance.json`；可复现工具：`tools/legacy/prepare_star_stingers_v87.py`。

## V87b 真实乐器版（关键事件音重建）

V87 首版（变调派生）试听被否：程序化感明显。本版改为**真实乐器录音**，不做变调与合成：

| 来源 | 作者 | 许可 | 使用 |
|---|---|---|---|
| [Kalimba Two-Notes](https://opengameart.org/content/kalimba-two-notes) | — | CC0 1.0 | 购买（原样双音确认） |
| [Marimba Samples](https://freesound.org/people/sgossner/packs/15684/) | sgossner / Sam Gossner | **CC BY 4.0（须署名）** | 轻点(C5)、旋转(D6)、胜利(C5-E5-B5)、败北(E3-C3) |
| [VSCO 2 CE Glockenspiel](https://freesound.org/people/sgossner/packs/21027/) | Sam Gossner / Versilian Studios | 公有领域（VSCO 2 CE） | 星位(F#6)、胜利末拍点缀(C6) |

序列音（胜利/败北）由真实单音以人性化时值（±8~15 ms，种子 87）与力度渐变排成；自然混响尾保留。处理与哈希见 `provenance.json`（`revision: v87b`）；可复现工具：`tools/legacy/prepare_real_instruments_v87b.py`。原始下载件保存在 `sources/real/`。

## V89 星声去锐

历史占位音：VSCO 2 CE F#6 录音，3 kHz 高架均衡 −6 dB、6 kHz 低通、6 ms 起音与 55 ms 收尾，长 0.30 秒。已被下方 V90 用户选定素材替换，`tools/legacy/soften_star_v89.py` 仅用于复现历史版本。

## V90 用户选定：卡通气泡的第一声（2026-10-18）

- 来源：[Mixkit — Cartoon bubble pop，编号 731](https://mixkit.co/free-sound-effects/bubble/)。
- 授权：[Mixkit Sound Effects Free License](https://mixkit.co/license/modal/sfxFree/)，原件与许可快照位于 `sources/mixkit/`。该素材不是 CC0；可以用于游戏成品，不可作为独立素材包再分发。
- 用户选择 8 个试听候选中的 03，并指定只用第一声。原素材约 0.52 秒、含两下气泡；当前截取 0.000–0.250 秒，排除约 0.270 秒开始的第二下。
- 保留试听版固定增益 −8.513 dB，仅收尾 5 ms 淡出；不变调、不加混响、不重新合成。48 kHz 双声道 PCM16，播放音量仍为 −13 dB，260 ms 限流继续有效。
- 当前星声重建：`python3 tools/legacy/prepare_star_v90.py`。若重跑历史音频构建脚本，最后执行此工具恢复已选音效；不改其他事件声音。

## V95 败北与武器音

败北已替换为用户选定的 Mixkit 2876「Funny fail low tone」（试听 11），原始音色和速度保留；不再播放独立的命中／受击声。武器攻击改用各自素材，详见 [V95 署名](assets/audio/sfx/weapons/CREDITS.md)。其他原有事件 WAV 未替换。

## V97 用户选定 25：清脆点击

- 来源：[Cartoon Pop (Clean) / unfa](https://freesound.org/people/unfa/sounds/245645/)，CC0。官方公开 HQ MP3 预览、源页与许可保存在 `sources/unfa/`。
- `click.wav` 和 `pick.wav` 均逐字节采用用户选中的 `audio-audition-sfx4-2026-10-19/single/25_click.wav`，单次约 0.172 秒。固定增益 -9.27635 dB、末尾 8 ms 淡出，48 kHz 双声道 PCM16；无变调、变速或音层叠加。
- 物品点选在按下抓取入口发出 `pick`，故按钮 `click` 与物品 `pick` 一起接入。V91 的一次手势一声规则保留，展示详情不会再发声。
- V95 声骸攻击用独立 `assets/audio/sfx/weapons/echo.wav`，未随抓取声更换。星声、武器、BGM、胜败音与其他反馈保持原文件；三声递进铜管仍是项目外试听稿。

## V98 用户选定 31：连贯三声胜利铜管＋09鼓掌

- 小号录音来自 [VSCO 2 Community Edition](https://github.com/sgossner/VSCO-2-CE)，Sam Gossner / Versilian Studios，CC0。采用同一套长音录音的 A#3、D4、F4，保留原音高和速度，截短中段并以 55 ms 交叉淡化接回原录音的自然收音；起音为 0、0.225、0.475 秒。
- 鼓掌为已选 09 小群体鼓掌，源素材 Mixkit 523，使用 [Mixkit Sound Effects Free License](https://mixkit.co/license/modal/sfxFree/)。从 0.64 秒淡入，较已选鼓掌单次样本衰减 8 dB。原件、许可和精确处理参数位于 `sources/victory31/`。
- `win.wav` 与用户确认的 `audio-audition-sfx6-2026-10-20/single/31_victory.wav` 逐字节一致，3.34 秒、48 kHz 双声道 PCM16。三声铜管和鼓掌已预混成单文件，不在运行时额外叠加；既有胜利播放音量 -6 dB、事件限流和 BGM 压低保留。
- 本次仅替换胜利事件音。已选 25 点击、11 败北、V96 武器乱斗混音、V90 星声与 V94 BGM 保持原文件。

## V99 开战与结算反馈（2026-10-20）

- `start.wav` 改为逐字节复用 V97 用户选定的 25 号 Cartoon Pop (Clean) / unfa（CC0），运行音量 −7 dB。开战按钮取消额外的通用点击声；实际成功进入战斗后只播放一次开战音，鼠标与快捷键共用入口。
- `win.wav` 继续使用已批准 31 号，不改素材；运行音量从 −6 dB 提高到 −2 dB。胜败结算立即停止 BGM，不再仅降低配乐音量。
- 其他事件 WAV、武器声音及 BGM 原文件不变。当前校验见 `docs/feedback-v99/checks/asset-validation.json`。


---
来源：assets/audio/music/CREDITS.md

# V94 背景音乐署名

Music by **PeriTune** — [peritune.com](https://peritune.com/)

| 游戏场景 | 曲名 | 作者原始发布页 | 所用素材 |
| --- | --- | --- | --- |
| 选人、整备、商店、详情、配方 | Positive_Happy（试听 2） | https://peritune.com/blog/2019/01/06/positive_happy/ | 作者循环版 OGG，80 秒 |
| 战斗（结算即停止） | Battle_Fun（试听 4） | https://peritune.com/blog/2021/04/13/battle_fun/ | 作者循环版 OGG，约 72.65 秒 |

Both tracks are licensed under **[Creative Commons Attribution 4.0 International](https://creativecommons.org/licenses/by/4.0/)**. The author's [licence page](https://peritune.com/about/) confirms that works released before March 2026 retain CC BY 4.0. These tracks were released in 2019 and 2021. Checked 2026-10-19.

原始 OGG 文件逐字节保留；无再合成、无变速、无变调、无重新压缩。V99 按用户反馈再降低 3 dB：整备 −17.34 dB，战斗 −21.46 dB。保留 0.65 秒场景交叉淡化，以及战斗暂停时约 −6 dB 的衰减；胜败结算与终局立即停止两条音乐声部，让结果音效独立收尾，下一轮恢复整备音乐。

下载地址、SHA-256 与时长见 [provenance.json](assets/audio/music/provenance.json)。发布游戏时应随包保留此署名和许可链接。


---
来源：assets/audio/sfx/weapons/CREDITS.md

# V95 武器攻击音与已选败北音

| 游戏用途 | 来源原名／ID | 官方来源 |
| --- | --- | --- |
| 迅刀 | Swift Sword Strike / 2166 | https://mixkit.co/free-sound-effects/swish/ |
| 长刃 | Air in a hit / 2161 | https://mixkit.co/free-sound-effects/punch/ |
| 配枪 | Short laser gun shot / 1670 | https://mixkit.co/free-sound-effects/laser/ |
| 臂铠 | Soft quick punch / 2151 | https://mixkit.co/free-sound-effects/punch/ |
| 音感仪 | Magic bubbles spell / 2999 | https://mixkit.co/free-sound-effects/bubble/ |
| 声骸 | V53 已有 BMacZero 气泡录音 | https://opengameart.org/content/bubble-sound-effects |
| 败北 | Funny fail low tone / 2876，用户选择试听 11 | https://mixkit.co/free-sound-effects/cartoon/ |

Mixkit 素材使用 [Sound Effects Free License](https://mixkit.co/license/modal/sfxFree/)，允许用于游戏成品，不可作为独立素材库再分发。声骸沿用 BMacZero 的 CC0 素材。来源页、原件 SHA-256、截取区间和音量参数见 `provenance.json`；Mixkit 原件及许可保存在 `sources/`，不作为游戏场景内容公开提供。

武器音只作截取、末尾 10 ms 淡出、固定增益与格式转换；不变调、不变速、不用抓取或旋转音转调来模拟武器。源片段保持单个动作长度，臂铠的拳击录音仅在出拳时响一次，不再附加独立命中声。声骸音直接保留旧版本录音。

V96 追加修正：仅配枪 `pistol.wav` 在以上 V95 片段基础上削弱高频（3.5 kHz 高架 -12 dB、10 kHz 二阶低通、2 ms 起音淡入）；不再归一化、不变调、不变速。原 V95 片段、前后频谱和哈希保存在 `docs/audio-v96/`，完整参数补充于 `provenance.json`。其余录音保持原字节。

败北文件位于 `assets/audio/sfx/ui/lose.wav`，与用户选定试听 11 的单次版本完全相同。原有点击、抓取、星位、胜利与其他事件 WAV 未在本轮替换。新点击与叠铜管的胜利声位于项目外试听目录，待用户选择。


---
Kenney Particle Pack — https://kenney.nl/assets/particle-pack （CC0）
	

	Particle Pack (1.1)

	by Kenney Vleugels (Kenney.nl)

	Additional credit for creating filter templates:
	Indigo Ray, Craig Nisbet, Zoltan Erdokovy, Heliagon, ThreeDee, Killst4r and Tim2501

			------------------------------

	License (Creative Commons Zero, CC0)
	http://creativecommons.org/publicdomain/zero/1.0/

	You may use these assets in personal and commercial projects.
	Credit (Kenney or www.kenney.nl) would be nice but is not mandatory.

			------------------------------

	Donate:   http://support.kenney.nl
	Request:  http://request.kenney.nl

	Follow on Twitter for updates: @KenneyNL (www.twitter.com/kenneynl)
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

败北文件位于 `assets/audio-v53/lose.wav`，与用户选定试听 11 的单次版本完全相同。原有点击、抓取、星位、胜利与其他事件 WAV 未在本轮替换。新点击与叠铜管的胜利声位于项目外试听目录，待用户选择。

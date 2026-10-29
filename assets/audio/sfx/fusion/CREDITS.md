# V102 短合成声

合成开始及材料靠拢保持无声。成品在 0.94 秒开始出现时，只播放一次 0.26 秒的柔和气泡；不播放 V101 的连续聚拢声或长尾。

- 素材：**Bubble Sound Effects / bubbles-single2**。
- 作者：**BMacZero / Brian MacIntosh**。
- [来源](https://opengameart.org/content/bubble-sound-effects) · [CC0 1.0](https://creativecommons.org/publicdomain/zero/1.0/)。
- 原件继续留在 `assets/audio-v53/sources/bubbles-single2.wav`；原许可记录见 `assets/audio-v53/CREDITS.md`。

取原录音 0.00–0.26 秒，35 Hz 高通、3.6 kHz 温和低通、4 ms 淡入和 35 ms 淡出，固定增益匹配。48 kHz 单声道 PCM16；不变调、不变速、不叠层、不合成旋律、不增加混响。运行音量为 −7 dB，继续使用独立合成声部；取消、离开或新合成只停止该声部。

运行 `python3 tools/prepare_fusion_v102.py` 从工程保留的原件重建。确切哈希及测量见 [provenance.json](provenance.json)。未自动播放；技术检查不代表玩家已经确认听感。

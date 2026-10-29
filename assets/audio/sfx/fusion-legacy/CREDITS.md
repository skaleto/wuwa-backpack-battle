# V101 合成：聚拢与落成

只使用工程中已留存、已核对许可的真实素材。没有振荡器合成、变调、变速、铜管旋律或新的成功提示音；已认可的点击、抓取、开战、胜败、星位、武器与 BGM 文件保持原字节。

| 素材 | 作者 | 来源与许可 | 用途 |
| --- | --- | --- | --- |
| Air in a hit / 2161 | Mixkit | [来源](https://mixkit.co/free-sound-effects/swish/) · [Sound Effects Free License](https://mixkit.co/license/modal/sfxFree/) | 三次轻柔气流，从左右向中间收拢 |
| Bubble Sound Effects / single1、single2 | BMacZero / Brian MacIntosh | [来源](https://opengameart.org/content/bubble-sound-effects) · [CC0 1.0](https://creativecommons.org/publicdomain/zero/1.0/) | 材料轻响、落成后的柔软主体与余响 |
| Cartoon bubble pop / 731，仅第一声 | Mixkit | [来源](https://mixkit.co/free-sound-effects/bubble/) · [Sound Effects Free License](https://mixkit.co/license/modal/sfxFree/) | 中央的清脆落成起音 |

Mixkit 许可允许用于游戏成品，不允许作为独立素材库再分发。原件与许可证据继续留在 `assets/audio-v95/sources/`、`assets/audio-v53/sources/`；确切相对路径、原件 SHA-256、截取区间、滤波、声像、增益与输出哈希见 [provenance.json](provenance.json)。

运行 `python3 tools/prepare_fusion_v101.py` 可从工程内原件重建全部三个 WAV，需 ffmpeg。输出为 48 kHz 双声道 PCM16。温和低通用于控制高频，素材维持原音高和播放速度；左、右、较居中的三个轻响逐步靠向中央，气流随后汇聚。落成由中央气泡起音与较低的气泡主体叠合，不拼接乐器旋律。

- `fusion_gather.wav`：动画开始播放，1.00 秒。
- `fusion_land.wav`：动画跨过 0.94 秒、成品开始出现时播放，0.48 秒；自然动画结束不裁掉最后约 0.17 秒尾音。
- `fusion_preview.wav`：将上述两段原样置于 0.00 与 0.94 秒的 1.42 秒完整试听。它仅供用户主动播放，不由游戏或测试自动播放。

取消或跳过只停止两个合成声部；没有定时器预约后续音。新一轮合成先清理上一轮声音。无窗口 Dummy 驱动测试证明时序与取消行为；PCM 检查证明资源格式、峰值、长度及混合关系，均不代表已由人耳试听认可。

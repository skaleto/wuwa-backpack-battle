# V120 星芯与轮廓光点

`effect_stars.png`为内置imagegen生成的原始透明PNG，1774×887，未裁切、重采样或后期改图。运行时使用manifest中两块source rect。灰态与金态用相同轮廓；动画、扩散和亮度由引擎独立绘制。

- 原始路径：`private-source`
- SHA256：`32b10159c5fb753697b09af45bafde892f25b85e9ae517ec8ba3fc08a3f9a843`
- 参考：已有星位图集与V119开场软淡彩画面。

生成要求：Create an original transparent sprite atlas for this cute pastel hand-painted Q-style inventory game. Exactly TWO isolated matching five-point star icons in a single horizontal row on a 2:1 canvas, identical silhouette, orientation and size, fully contained with generous transparent gutter. Left pale pearl-lavender with silver-cream rim and mid-purple shading; right warm honey-gold/apricot with a small cream highlight and thin warm rim. Round plump short tips, soft valleys, slightly organic, clean illustrated shading readable at 28 px. No hard faceting, angular nested stars, black border, face, text, sparkles, outer halo, particles or drop shadow. A soft luminous sugar star, not a plastic button or metal badge. Only cores; the engine animates emitted light.

`glint-anchors.json`由`tools/build_glint_anchors_v120.py`只读原物品PNG的alpha和邻近颜色生成；63件金／红物品各自记录路径、尺寸及原图哈希。没有改动原物品图片。资源替换后重建该表，运行时不做像素扫描。

光点复用项目已有Kenney Particle Pack的`star_04`与`light_02`原始贴图；授权为CC0，原始许可见`assets/vfx/kenney/LICENSE.txt`。每件金色最多3个、红色最多5个，沿图案轮廓短距离逸出；具体预算与确定性由渲染回归检查。

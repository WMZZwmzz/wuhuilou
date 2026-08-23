# 音效资源授权记录

《无回楼》垂直切片 Demo 的外部音效资源(2026-08 引入)。全部允许商用;
CC0 无署名要求,CC-BY 3.0 要求署名(见下)。资源缺失时 `scripts/sfx.gd`
自动回退为程序化合成,删除本目录任意文件游戏仍可运行。

wav 均已由原始 24bit/float32 转换为 16bit PCM 并做响度标准化
(转换脚本逻辑:RMS 目标 + 峰值保护,一次性离线处理)。

| 文件 | 用途 | 来源 | 作者 | 授权 |
|---|---|---|---|---|
| `ding.ogg` | 电梯到站铃 | [Kenney Impact Sounds](https://kenney.nl/assets/impact-sounds)(impactBell_heavy_000) | Kenney | CC0 |
| `click.ogg` | UI/交互咔哒 | [Kenney Interface Sounds](https://kenney.nl/assets/interface-sounds)(click_002) | Kenney | CC0 |
| `flash.ogg` | 手电开关 | 同上(switch_004) | Kenney | CC0 |
| `thud.ogg` | 影子人/电梯闷响 | Kenney Impact Sounds(impactSoft_heavy_000) | Kenney | CC0 |
| `footstep_0..4.ogg` | 楼道脚步 ×5 变体 | Kenney Impact Sounds(footstep_concrete_000..004) | Kenney | CC0 |
| `sting.wav` | 惊吓刺音 | [Horror Sound Effects Library](https://opengameart.org/content/horror-sound-effects-library)(Stab_Knife_00) | Little Robot Sound Factory | CC-BY 3.0 ¹ |
| `whisper_0..5.wav` | 低理智耳语/呼吸 ×6 变体 | 同上(Breath_Scared_00..05) | Little Robot Sound Factory | CC-BY 3.0 ¹ |
| `drone.wav` | 常驻环境低鸣(60s 循环) | 同上(Ambience_MonstersBelly_00) | Little Robot Sound Factory | CC-BY 3.0 ¹ |
| `elevator_ride.wav` | 乘梯运行嗡鸣(9.6s 循环) | 同上(Evil_Machine_Loop_00) | Little Robot Sound Factory | CC-BY 3.0 ¹ |
| `drip.wav` | 4F 诊所滴水(7.8s) | 同上(Blood_Dripping_Loop_01) | Little Robot Sound Factory | CC-BY 3.0 ¹ |
| `heart_slow.wav` | 心跳·慢(理智<50) | [Heartbeat sounds](https://opengameart.org/content/heartbeat-sounds)(heartbeat_slow_0) | bart | CC0 |
| `heart_fast.wav` | 心跳·快(理智<25) | 同上(heartbeat_fast_0) | bart | CC0 |
| `music_box.ogg` | 13F/结局八音盒 | [4 Music Box Tracks](https://opengameart.org/content/4-music-box-tracks)(musicbox1_spooky_waltz) | rubberduck | CC0 |

¹ CC-BY 3.0 署名:作品须注明 "Sound effects by Little Robot Sound Factory
(https://opengameart.org/content/horror-sound-effects-library)"。作者原官网
域名已失效,署名链接指向 OpenGameArt 资源页。

仍然程序化合成的音效:`sting_n`(刺音噪声层)、`mahjong`(麻将碰撞,
含音高/节奏随机化)、外部资源全部缺失时的回退音(`scripts/sfx.gd`)。

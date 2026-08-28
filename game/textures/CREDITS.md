# 贴图资源授权记录

《无回楼》垂直切片 Demo 的外部贴图资源(2026-08 引入)。全部 CC0,可商用、
无署名要求(仍按下表留档以便溯源)。资源缺失时 `scripts/texgen.gd` 的
`load_external()` 自动跳过该槽位,消费方走程序化贴图,**删除本目录游戏仍可运行**。

| 文件 | 用途 | 来源 | 作者 | 授权 |
|---|---|---|---|---|
| `cloth_cotton.jpg` | 棉针织 albedo(病号服/衬衫/纸衣等浅色布料) | [Poly Haven cotton_jersey](https://polyhaven.com/a/cotton_jersey) | Poly Haven 社区 | CC0 |
| `cloth_denim.jpg` | 丹宁 albedo(工装/外套等耐磨布料) | [Poly Haven denim_fabric](https://polyhaven.com/a/denim_fabric) | Poly Haven 社区 | CC0 |
| `cloth_satin.jpg` | 素绉缎 albedo(寿衣/窗帘/礼服等有光泽织物) | [Poly Haven crepe_satin](https://polyhaven.com/a/crepe_satin) | Poly Haven 社区 | CC0 |
| `leather_brown.jpg` | 棕皮革 albedo(皮箱/皮鞋/座椅) | [Poly Haven brown_leather](https://polyhaven.com/a/brown_leather) | Poly Haven 社区 | CC0 |

## 只收 albedo,法线一律程序化

每套扫描原始都带 diffuse + normal(1K JPG),但**只有 diffuse 入库**,normal
一律不引入,继续用 `texgen.gd` 程序化生成的 `cloth_n` / `skin_n` 等。原因:
Godot 导入的 JPG/PNG 默认按 sRGB 采样(`compress/mode` + `normal_map` 约定写在
`.import` 里),而 `.import` 由 `--import` 自动生成、不宜手写;把法线图当 sRGB
纹理采样会破坏切线空间。为避免这类隐性错误,外部通道只开 albedo 一扇门。

同理,4 张图均为 1K 级别且未做缩放/重压缩(尺寸保留站方原值,故非严格方形),
平铺时以 `uv1_scale` 控制密度,与程序化贴图的用法一致。

## 人体部分为何仍是纯程序化

可达的 CC0 素材站(实测仅 Poly Haven 通畅)**没有任何人体皮肤/毛发扫描资源**,
所以皮肤、毛发、眼球继续由 `texgen.gd` 的 CPU 画布生成灰度基底 + Sobel 法线,
靠材质 albedo 染色。`EXT` 中已预留 `skin_fuzz` / `hair_card` / `eye_hetero` 三个
键位(当前无文件,`has()` 返回 false),将来放入同名 jpg/png 即自动替换。

仍然程序化的贴图:墙/地/顶(GPU 噪声着色器)、门与金属、玻璃、血迹、
`skin` / `skin_n` / `cloth` / `cloth_n` 回退版本、以及全部文本类贴图
(须知/讣告/日记/监控/画像/门牌等)。

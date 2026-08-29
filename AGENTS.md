# AGENTS.md —《无回楼》工作区须知

中式心理恐怖游戏《无回楼》的设计文档工作区,含一份基于 **Godot 4.7** 的可运行垂直切片 Demo。全部文档、代码注释均为简体中文,新内容保持中文。

## 目录结构

- `无回楼.md` — 设计文档总导航(根索引)。**新增/移动文档后必须同步更新此文件的链接**。
- `01-游戏介绍` ~ `09-视听设计` — 按主题拆分的设计文档,文件夹数字前缀决定阅读顺序。
- `game/` — Godot 4.7 垂直切片工程(15 层全流程:1F–13F + B1/B2)。
- `.zcode/plans/` — 历史实施计划,仅供参考。

## Demo 技术约束(game/)

- 引擎:Godot 4.7(Forward+ / D3D12)。本机编辑器可执行文件:`C:\Users\PC\Desktop\Godot_v4.7.2-stable_win64.exe`。
- **素材**:基础贴图与**全部法线**程序化生成(`scripts/texgen.gd`);**布料/皮革 albedo 为外部 CC0 扫描**(`game/textures/`,来源与授权见 `game/textures/CREDITS.md`,缺失时 `TexGen.load_external()` 跳过该槽位、消费方自动回退程序化贴图);皮肤与头发一律程序化(可达的 CC0 站无人体扫描,仅留 `skin_fuzz`/`hair_card`/`eye_hetero` 键位)。外部贴图**只收 albedo**——Godot 导入的 JPG 默认按 sRGB 采样,法线需关 sRGB 才正确。中文界面从系统字体加载(微软雅黑,缺失时回退默认字体)。导出正式版时需随包附带字体文件。
- 渲染:StandardMaterial3D PBR(roughness/metallic/clearcoat/程序化法线)+ 深色程序化天空作环境反射 + 阴影(PCF Soft)+ Environment 泛光/ACES 色调映射;低理智画面扭曲、色差与暗角由 `hud.gd` 的全屏后处理着色器完成。
- 结构:全部玩法逻辑为 GDScript——`scripts/main.gd` 总控(玩家/交互/电梯与六种异常/理智结算/结局死亡),`scripts/floor_*.gd` 为五个楼层,`scripts/hud.gd` 为全部 UI。唯一场景 `scenes/main.tscn` 只挂根脚本,内容均由代码搭建。
- 数值(理智/电量/体力/时钟/违规惩罚)以 `06-玩法机制/数值平衡表.md` 为准,改动需两处对齐(`scripts/state.gd` 的 `NUM`)。
- 运行时追加用户参数 `-- --debug` 出 QA 面板:楼层跳转、传送点位、调理智/电量/时间、直通结局。

## QA 流程(game/qa/)

无头全流程走查,断言覆盖:标题→1F 教学(手电/须知/监控)→乘梯异常(正确/错误两路)→2F/4F/7F 全谜题→13F 强制异常→结局结算→理智归零死亡→本层重试→6:00 时限死亡。

```bash
GODOT="/c/Users/PC/Desktop/Godot_v4.7.2-stable_win64.exe"
"$GODOT" --headless --path game --import                          # 新增/变更资源后先导入
"$GODOT" --headless --path game --script res://qa/qa_runner.gd   # 无头断言,退出码 0 = 全过
"$GODOT" --path game --script res://qa/qa_runner.gd              # 带渲染复跑,截图存 game/qa/shots/
powershell -NoProfile -ExecutionPolicy Bypass -File game/qa/brightgrid.ps1 game/qa/shots/02-1f-lobby.png   # 截图亮度网格,验证非黑屏
powershell -NoProfile -ExecutionPolicy Bypass -File game/qa/uicheck.ps1                                    # 像素级 UI 特征断言(标题朱砂行/CRT 扫描线/弹窗纸纹/死亡红带/结局亮像素)
```

改动 game/ 后必须跑无头走查,确认输出「失败项: 无 —— 全部通过 ✓」且零 `SCRIPT ERROR`。改动/新增 `game/sounds/` 下音频或 `game/textures/` 下贴图后须先跑 `--import` 再跑 QA(QA 收尾断言外部音效加载数,第 29 节断言外部贴图与建模量)。

**小改动免跑**:同时满足下列条件时可以不跑 QA,并在提交说明里注明「免 QA + 原因」——

- 不改行为的改动:注释、日志与弹窗措辞、说明书正文、文档内链接、安全的局部改名。
- 只作用于单个函数内部、不外溢到结算的取值微调(某个装饰偏移、某个材质系数),且不碰 `state.NUM`。
- 只动文档(`*.md`)、`game/qa/` 自身脚本或仓库配置(`.gitignore` 等),`game/` 玩法与资源未变。

**哪怕 diff 只有几行也必须跑**: `state.NUM` 数值;光照/材质/后处理参数(会挪动截图亮度基线,须连带 `brightgrid.ps1` 与带渲染复跑);HUD 布局、控件与文案排版(`uicheck.ps1` 按像素特征断言);「Demo 内部接口」一节列出的任何名字(含 `Humanoid` 生成器函数与 QA 依赖的 cfg 键);音频与贴图的增删。判定有疑时按「跑」处理——漏跑一次回归的代价高于一次走查。

⚠️ 陷阱:`qa_runner.gd` 的 `_run()` 内一旦出现 SCRIPT ERROR,协程中断且永远走不到末尾的 `quit(0)`,**Godot 进程会静默滞留**(表现为"QA 跑了半小时没完"),判断依据是日志里缺少「失败项:」行;此时需手动结束进程,且注意 `TaskStop` 只终止外层 shell,Godot 子进程要另行 `Stop-Process`。另:headless `--script` 中调用 `PrimitiveMesh.get_surface_arrays()`(CylinderMesh/SphereMesh/BoxMesh)会挂死进程,取网格真值只能走自家 `ArrayMesh` 生成器。

## Demo 内部接口(QA 脚本依赖,勿随意改名)

- 状态对象 `G`(`GameState` 实例,挂于场景根 `Main`):`floor_id / sanity / battery / has_flash / flash_on / cards / relics / time / playing / flags / pills / candles / violations / knows_pills / deaths / modal_open`
- 音效(`S` = `Sfx`):`play_buf(name, vol, pitch)`、`ding/click/flash/sting/whisper/thud/mahjong()`、`play_step(running)`、`heart(on, rate_ms)`、`drone(on)`、`elevator_ride(on)`、`music_box()`、`toggle_mute()`、`ext_loaded`(QA 断言用)
- 主控(`main.gd`,场景根节点名 `Main`):`player_pos / player_yaw / player_pitch / keys`(按键字典,键为 `Key` 枚举)、`current_inter`、`ride_to(floor, skip_anomaly)`、`tp(idx)`、`teleport_cycle()`、`change_sanity(v)`、`add_game_minutes(m)`、`start_ending()`、`interact_press()`
- HUD(`H`):弹窗判定用 `H.modal_visible()` 与 `H.modal_title.text`;选项点击用 `H.find_choice(文本[, 前缀匹配])` 返回 Button,以 `pressed.emit()` 触发。
- 人形建模:`Props.human_figure(m, cfg)` → `Humanoid.build(m, cfg)`,约定正面朝 -Z。cfg 键见 `props.gd` 注释(含 `face:"blurred"`、`alpha`、`fabric`)。返回**旧 8 键不变** `{root,head,arm_l/r,fore_l/r,hand_l/r}` + 骨架键 `{upper, hip_l/r, knee_l/r, ankle_l/r, legged, rig{scale,pose,stride,heel}}`;`skirt` / `robe` 坐姿 / `legless` 三种分支**不建腿**,对应枢轴为 `null`,驱动须先判 `legged`。
- 步态驱动:`HumanoidAnim`(静态注册表)—— `register(fig, opts)`、`tick_all(dt)`(仅 `main._process` 在 `floor_update` 之后调用)、`unregister_floor()`(`clear_scene` 必须调)、`breath_root(node, amp, hz, phase)`、`pulse_scale`、`last_slip`(QA 断言用)。**驱动只写 `upper` 与四肢枢轴,绝不写 root 的 position/rotation**(root 归楼层与 `look_at`)。参数集中在 `HumanoidAnim.GA`(渲染/动作常量,不进 `state.NUM`)。
- 静态合批:`Humanoid.merge_static(fig_root, cache_key)` 必须在摆好姿势之后调用,合并后骨架引用失效;cache_key 须含全部外观因子,楼层隔离用 `m.get_instance_id()`。缓存有 `MERGE_CACHE_MAX` 上限(LRU),`merge_cache_stats()` 供 QA 断言。
- QA 第 29 节依赖上述名字与 `Humanoid` 的生成器函数(`lathe/sculpt_sphere/tube/merge_static/flat_quad`),勿改名。

## 改文档前先读

- 改世界观/机制 → `02-世界观设定/核心设定.md`、`06-玩法机制/核心机制.md`
- 改楼层/点位 → `05-楼层设计/楼层主题设计.md`、`05-楼层设计/关卡白模与地图布局.md`
- 改数值 → `06-玩法机制/数值平衡表.md`
- 改剧情/结局 → `04-剧情/剧情总览与角色关系.md`、`04-剧情/时间线与真相.md`
- 未决事项记录在 `08-附录/待定与勘误.md`,不要在正文里留 TODO。

## 其他

- git 仓库(分支 `main`,远程 GitHub:https://github.com/WMZZwmzz/wuhuilou);删除/覆盖文件前先确认内容。
- 路径含中文(工作区名 `无回楼`),shell 命令注意加引号。

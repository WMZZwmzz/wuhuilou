# AGENTS.md —《无回楼》工作区须知

中式心理恐怖游戏《无回楼》的设计文档工作区,含一份基于 **Godot 4.7** 的可运行垂直切片 Demo。全部文档、代码注释均为简体中文,新内容保持中文。

## 目录结构

- `无回楼.md` — 设计文档总导航(根索引)。**新增/移动文档后必须同步更新此文件的链接**。
- `01-游戏介绍` ~ `09-视听设计` — 按主题拆分的设计文档,文件夹数字前缀决定阅读顺序。
- `game/` — Godot 4.7 垂直切片工程(15 层全流程:1F–13F + B1/B2)。
- `.zcode/plans/` — 历史实施计划,仅供参考。

## Demo 技术约束(game/)

- 引擎:Godot 4.7(Forward+ / D3D12)。本机编辑器可执行文件:`C:\Users\PC\Desktop\Godot_v4.7.2-stable_win64.exe`。
- **素材**:贴图、法线贴图程序化生成(`scripts/texgen.gd`);**音效为外部 CC0/CC-BY 资源**(`game/sounds/`,来源与授权见 `game/sounds/CREDITS.md`,资源缺失时 `scripts/sfx.gd` 自动回退程序化合成);中文界面从系统字体加载(微软雅黑,缺失时回退默认字体)。导出正式版时需随包附带字体文件。
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
```

改动 game/ 后必须跑无头走查,确认输出「失败项: 无 —— 全部通过 ✓」且零 `SCRIPT ERROR`。改动/新增 `game/sounds/` 下音频后须先跑 `--import` 再跑 QA(QA 收尾断言外部音效加载数)。

## Demo 内部接口(QA 脚本依赖,勿随意改名)

- 状态对象 `G`(`GameState` 实例,挂于场景根 `Main`):`floor_id / sanity / battery / has_flash / flash_on / cards / relics / time / playing / flags / pills / candles / violations / knows_pills / deaths / modal_open`
- 音效(`S` = `Sfx`):`play_buf(name, vol, pitch)`、`ding/click/flash/sting/whisper/thud/mahjong()`、`play_step(running)`、`heart(on, rate_ms)`、`drone(on)`、`elevator_ride(on)`、`music_box()`、`toggle_mute()`、`ext_loaded`(QA 断言用)
- 主控(`main.gd`,场景根节点名 `Main`):`player_pos / player_yaw / player_pitch / keys`(按键字典,键为 `Key` 枚举)、`current_inter`、`ride_to(floor, skip_anomaly)`、`tp(idx)`、`teleport_cycle()`、`change_sanity(v)`、`add_game_minutes(m)`、`start_ending()`、`interact_press()`
- HUD(`H`):弹窗判定用 `H.modal_visible()` 与 `H.modal_title.text`;选项点击用 `H.find_choice(文本[, 前缀匹配])` 返回 Button,以 `pressed.emit()` 触发。

## 改文档前先读

- 改世界观/机制 → `02-世界观设定/核心设定.md`、`06-玩法机制/核心机制.md`
- 改楼层/点位 → `05-楼层设计/楼层主题设计.md`、`05-楼层设计/关卡白模与地图布局.md`
- 改数值 → `06-玩法机制/数值平衡表.md`
- 改剧情/结局 → `04-剧情/剧情总览与角色关系.md`、`04-剧情/时间线与真相.md`
- 未决事项记录在 `08-附录/待定与勘误.md`,不要在正文里留 TODO。

## 其他

- git 仓库(分支 `main`,远程 GitHub:https://github.com/WMZZwmzz/wuhuilou);删除/覆盖文件前先确认内容。
- 路径含中文(工作区名 `无回楼`),shell 命令注意加引号。

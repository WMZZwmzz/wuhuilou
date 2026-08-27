class_name GameState
extends RefCounted
## 全局游戏状态与数值(对齐《06-玩法机制/数值平衡表》初版建议值,勿单处改动)

const NUM := {
	"darkDrain": 2.0,      # 黑暗理智流失/秒
	"flashDrain": 0.3,     # 开手电理智流失/秒
	"safeHeal": 0.5,       # 安全区理智回复/秒
	"violation": 15.0,     # 违反规则惩罚
	"contactDrain": 5.0,   # 接触性事件(Demo 未实现逐秒接触流失,B1 被抓/9F 黑影为一次性扣值)
	"batteryDrain": 1.0,   # 手电耗电/秒
	"batteryGain": 50.0,   # 换电池回复
	"runCost": 10.0,       # 奔跑体力/秒
	"staminaRegen": 8.0,   # 体力回复/秒
	"walkSpeed": 2.8,
	"runSpeed": 5.2,
}

var playing := false
var paused := false
var modal_open := false
var riding := false      # 乘梯转场中:锁旧楼层交互,防双程竞态
var sanity := 100.0
var battery := 50.0
var has_flash := false
var flash_on := false
var stamina := 100.0
var stamina_lock := false
var time := 0.0          # 游戏内分钟,0:00 起,360 = 6:00 死亡
var batteries := 1
var pills := {"a": 0, "b": 0}
var candles := 0
var knows_pills := false
var relics := 0
var relic_names: Array = []
var cards := {"3F": false, "4F": false, "5F": false, "6F": false, "7F": false,
	"8F": false, "9F": false, "10F": false, "11F": false, "12F": false,
	"13F": false, "B1": false, "B2": false}
var floor_id := "1F"
var deaths := 0
var violations := 0
var flags := {}          # 各层谜题/事件旗标(死亡保留)
var candle_timer := 0.0
var running := false
var crouching := false   # 蹲伏状态(3F 躲苏梅 / B1 躲老周判定用,每帧由 main 更新)
# 注:无 reset_run()——重开一律走 get_tree().reload_current_scene(),状态随场景整体重建。

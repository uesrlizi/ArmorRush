extends Node
## 跨场景跑局状态（autoload 名：RunState）。
## 分数/关卡数/用时跨关累计：Main 每次击杀回写分数、战斗中逐帧累加用时，
## 新场景 _ready 取走接着算；死亡重开=新一局（Main 调 start_run 全部归零重掷）。
## 黑场交接旗标：转场前置位，新场景 _ready 取走后跳过启动页直接进战斗
## （直接从编辑器启动某一场景时旗标为空，照常走启动页，方便单关测试）。
## 关卡轮换袋：入口场景"开始游戏"调 start_run() 清分并抽第一关（只从
## FIRST_POOL 白名单抽——不在白名单里的场景永远不会当首关）；此后每次通关
## draw_next() 从轮换袋抽下一关，袋空整袋重洗——每 N 关全场景恰好各出现
## 一次、周期内不重复，且相邻两关永不相同（袋边界抽中上一关即换抽）。
## 新场景登记进 SCENES 即入池。局内循环 v2（design/run_loop.md §1）：
## 固定 RUN_NORMAL_LEVELS 个普通关 + 第 RUN_NORMAL_LEVELS+1 关 = RUSH 终局
## （没抽到的场景=连战阵容，逐台跳场景），阵容打空=通关（run_complete，
## draw_next 返回 ""）；总开关 RUN_LOOP_ENABLED=false 时整套退回旧的无限
## 滚动关（开关与细则全在 balance_global.gd）。

const SCENES: Array[String] = [
	"res://scenes/world/world_1.tscn", # 一 锈雨废都
	"res://scenes/world/world_2.tscn", # 二 精炼所工业带
	"res://scenes/world/world_3.tscn", # 三 雪原警戒点
	"res://scenes/world/world_4.tscn", # 四 珊瑚辐合夜
	"res://scenes/world/world_5.tscn", # 五 破晓云廊
	"res://scenes/world/world_6.tscn", # 六 赤沙矿区
	"res://scenes/world/world_7.tscn", # 七 溺海都会
	"res://scenes/world/world_8.tscn", # 八 镜盐之原
]
## 开局第一关候选（"只包含"白名单：新场景默认不进这里，除非允许它当第一关；
## 加场景时只动 SCENES，白名单按需加）。
const FIRST_POOL: Array[String] = [
	"res://scenes/world/world_1.tscn",
	"res://scenes/world/world_2.tscn",
	"res://scenes/world/world_3.tscn",
]

var score := 0
var stage := 1 # 本局第几关：start_run 归 1，每次 draw_next 进下一关 +1（直接开某关测试=1）
var play_time := 0.0 # 本局累计用时（秒，正计时）：Main 只在战斗中累加，跨关延续
var hold_chapter := false # autotest 置真：击败 BOSS 不切场景（探针需要世界原地活着）
var rush_active := false # RUSH 终局进行中（=第 5 关）：Spawner 落地即刷 BOSS+停杂兵，BOSS 血量打折
var rush_lineup: Array[String] = [] # RUSH 连战阵容（本局没抽到的场景）：逐台跳场景，打空=通关
var rush_total := 0 # RUSH 阵容总台数（进 RUSH 时定）：进度「最终战 n/总」的分母
var run_complete := false # 通关记号：阵容打空时置真，draw_next 返回 ""，Main 原地出通关结算
var handover_hp := -1 # RUSH 击破间不回血：击败时记下的玩家血量，下一台 BOSS 场景取走落地（-1=不携带）
## 录制隐藏档（HUD 接 F1/F2，跨章/跨局延续）：0=正常；1=F1 隐顶栏信息 HUD+结算
## 面板，语音播报（含字幕文字）一并停；2=F2 在 1 的基础上连头顶血条/气槽、
## BOSS 名条/血条/冲击条、WARNING 全隐=画面完全无 UI。状态正本在此单一存放，
## HUD 每次进场景落地即沿用（录制多章不用重按）。
var ui_tier := 0

var _handoff := false
var _touch_holds: Array[Dictionary] = [] # 换场景时仍被按住的触控指（旧场景触控件离场暂存，新场景认领）
var _bag: Array[String] = [] # 当前轮换袋剩余未抽的场景
var _last := "" # 上一关场景路径：draw_next 相邻防撞用
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()


## 章末转场调用：下一关跳过启动页。
func begin_handoff() -> void:
	_handoff = true


## 新场景 _ready 取走交接旗标（取即清，只消费一次）。
func take_handoff() -> bool:
	var pending := _handoff
	_handoff = false
	return pending


## 触控跨关交接（章末黑场换场景用）：还按着的摇杆/按钮在旧场景离场前把
## （动作名, 触摸索引, 最后视口坐标）暂存到这里；新场景 TouchControls._ready
## 取走分发给同款控件原地认领——按住的手指跨关不脱手。摇杆（按住型）压回
## 动作续走；跳/斩按钮（边沿型）只认领不压回，与键盘按住不自动触发同语义。
## 死亡重开路径离场前先 release() 清了认领，不会暂存；取即清，只交接一次。
func stash_touch_hold(action: String, index: int, position: Vector2) -> void:
	_touch_holds.append({"action": action, "index": index, "position": position})


## 新场景 TouchControls._ready 取走全部暂存（取即清）。
func take_touch_holds() -> Array[Dictionary]:
	var holds := _touch_holds
	_touch_holds = []
	return holds


## 入口场景"开始游戏"调用：清分、关卡数与用时归零、整袋重洗、按白名单抽第一关
## 并返回场景路径。死亡重开也走这里（新一局=重新掷骰，哪里死不再哪里复活）。
func start_run() -> String:
	score = 0
	stage = 1
	play_time = 0.0
	rush_active = false
	rush_lineup = []
	rush_total = 0
	run_complete = false
	handover_hp = -1
	_touch_holds = [] # 新一局不带上一局的残指（死亡路径本就不暂存，双保险）
	_bag = SCENES.duplicate()
	var first: String = FIRST_POOL[_rng.randi_range(0, FIRST_POOL.size() - 1)]
	_bag.erase(first)
	_last = first
	return first


## 通关转场调用。旧制（RUN_LOOP_ENABLED=false）：关卡数 +1，轮换袋抽下一关
## （袋空整袋重洗、相邻防撞）——无限滚动。新制（design/run_loop.md §1）：前
## RUN_NORMAL_LEVELS 关照旧抽袋；之后进 RUSH 终局——本局没抽到的场景即连战
## 阵容（多于 RUN_RUSH_COUNT 台时随机留 3 台），stage 钉在 RUSH 关号上逐台
## 跳场景；阵容打空返回 ""（run_complete 置真）：Main 原地出通关结算。
func draw_next() -> String:
	if not BalanceGlobal.RUN_LOOP_ENABLED:
		return _draw_next_classic()
	if rush_active:
		if rush_lineup.is_empty():
			run_complete = true
			return ""
		return rush_lineup.pop_front()
	stage += 1
	if stage > BalanceGlobal.RUN_NORMAL_LEVELS:
		_enter_rush()
		return rush_lineup.pop_front()
	return _draw_from_bag()


## 旧制抽关：无限滚动（总开关关掉时 draw_next 走这里，行为与改前逐行一致）。
func _draw_next_classic() -> String:
	stage += 1
	return _draw_from_bag()


## 从轮换袋抽下一关并移出（袋空则整袋补满重洗）。
## 相邻防撞：抽中上一关就换抽袋里另一张——袋内无重复，换抽必不同；
## 袋只剩 1 张时它必不是上一关（同袋不重复，上一关已抽走），直接抽。
func _draw_from_bag() -> String:
	if _bag.is_empty():
		_bag = SCENES.duplicate()
	var idx := _rng.randi_range(0, _bag.size() - 1)
	if _bag.size() > 1 and _bag[idx] == _last:
		idx = (idx + _rng.randi_range(1, _bag.size() - 1)) % _bag.size()
	var next: String = _bag.pop_at(idx)
	_last = next
	return next


## 进 RUSH 终局：普通抽袋剩下的场景=连战阵容（7 场景池=剩余全部，每局恰好
## 看满 7 台 BOSS；池变大后从没抽到的里随机留 RUN_RUSH_COUNT 台）。
## stage 钉在 RUSH 关号（第 RUN_NORMAL_LEVELS+1 关）：三台 BOSS 的跳场景共用
## 这一个关号，HUD 与结算都报它。
func _enter_rush() -> void:
	rush_active = true
	stage = BalanceGlobal.RUN_NORMAL_LEVELS + 1
	var pool := _bag.duplicate()
	while pool.size() > BalanceGlobal.RUN_RUSH_COUNT:
		pool.pop_at(_rng.randi_range(0, pool.size() - 1))
	rush_lineup = pool
	rush_total = pool.size()
	_bag = [] # 普通袋功成身退：此后只走阵容队列


## 跑局进度文案（HUD 顶栏与结算共用的唯一出处）：返回 [标签, 读数]。
## 新制带分母让玩家看见终点：普通关「关卡 4/5」，RUSH「最终战 1/3」（第几台/
## 阵容台数；已弹出的台数=当前这台）。旧制无终点，照旧「关卡 N」。
func progress_parts() -> PackedStringArray:
	if not BalanceGlobal.RUN_LOOP_ENABLED:
		return PackedStringArray(["关卡", str(stage)])
	if rush_active:
		return PackedStringArray(["最终战", "%d/%d" % [
				rush_total - rush_lineup.size(), rush_total]])
	return PackedStringArray(["关卡", "%d/%d" % [
			stage, BalanceGlobal.RUN_NORMAL_LEVELS + 1]])


## 新场景 _ready 取走携带血量（取即清）：RUSH 击破间不回血的落地端。
## -1=不携带（满血开场照旧）。
func take_handover_hp() -> int:
	var value := handover_hp
	handover_hp = -1
	return value

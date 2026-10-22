extends Node
## 跨场景跑局状态（autoload 名：RunState）。
## 分数跨关累计：Main 每次击杀后回写，新场景 _ready 取走接着算；
## 死亡重开=新一局（Main 调 start_run 清分重掷）。
## 黑场交接旗标：转场前置位，新场景 _ready 取走后跳过启动页直接进战斗
## （直接从编辑器启动某一场景时旗标为空，照常走启动页，方便单关测试）。
## 关卡轮换袋：入口场景"开始游戏"调 start_run() 清分并抽第一关（只从
## FIRST_POOL 白名单抽——不在白名单里的场景永远不会当首关）；此后每次通关
## draw_next() 从轮换袋抽下一关，袋空整袋重洗——每 N 关全场景恰好各出现
## 一次、周期内不重复，且相邻两关永不相同（袋边界抽中上一关即换抽）。
## 新场景登记进 SCENES 即入池；没有末章概念，通关永远滚动。

const SCENES: Array[String] = [
	"res://scenes/world/world_1.tscn", # 一 锈雨废都
	"res://scenes/world/world_2.tscn", # 二 精炼所工业带
	"res://scenes/world/world_3.tscn", # 三 雪原警戒点
	"res://scenes/world/world_4.tscn", # 四 珊瑚辐合夜
	"res://scenes/world/world_5.tscn", # 五 破晓云廊
	# 六「赤沙矿区」暂时出池（2026-10-22：BOSS「赤轮」待返工，正常入口抽不到；
	# 编辑器直跑 world_6.tscn 仍可单关测试。返工验收后取消下行注释即恢复轮换）：
	# "res://scenes/world/world_6.tscn",
]
## 开局第一关候选（"只包含"白名单：新场景默认不进这里，除非允许它当第一关；
## 加场景时只动 SCENES，白名单按需加）。
const FIRST_POOL: Array[String] = [
	"res://scenes/world/world_1.tscn",
	"res://scenes/world/world_2.tscn",
	"res://scenes/world/world_3.tscn",
]

var score := 0
var hold_chapter := false # autotest 置真：击败 BOSS 不切场景（探针需要世界原地活着）

var _handoff := false
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


## 入口场景"开始游戏"调用：清分、整袋重洗、按白名单抽第一关并返回场景路径。
## 死亡重开也走这里（新一局=重新掷骰，哪里死不再哪里复活）。
func start_run() -> String:
	score = 0
	_bag = SCENES.duplicate()
	var first: String = FIRST_POOL[_rng.randi_range(0, FIRST_POOL.size() - 1)]
	_bag.erase(first)
	_last = first
	return first


## 通关转场调用：从轮换袋抽下一关并移出（袋空则整袋补满重洗）。
## 相邻防撞：抽中上一关就换抽袋里另一张——袋内无重复，换抽必不同；
## 袋只剩 1 张时它必不是上一关（同袋不重复，上一关已抽走），直接抽。
func draw_next() -> String:
	if _bag.is_empty():
		_bag = SCENES.duplicate()
	var idx := _rng.randi_range(0, _bag.size() - 1)
	if _bag.size() > 1 and _bag[idx] == _last:
		idx = (idx + _rng.randi_range(1, _bag.size() - 1)) % _bag.size()
	var next: String = _bag.pop_at(idx)
	_last = next
	return next

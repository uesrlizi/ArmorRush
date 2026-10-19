extends Node
## 跨场景跑局状态（autoload 名：RunState）。
## 分数跨章累计：Main 每次击杀后回写，新章 _ready 取走接着算；
## 章内死亡重开不走这里（Main 重开时清零）。
## 黑场交接旗标：章末转场前置位，新章 _ready 取走后跳过启动页直接进战斗
## （直接从编辑器启动某一章时旗标为空，照常走启动页，方便单章测试）。

var score := 0
var hold_chapter := false # autotest 置真：击败 BOSS 不切章（探针需要世界原地活着）

var _handoff := false


## 章末转场调用：下一章跳过启动页。
func begin_handoff() -> void:
	_handoff = true


## 新章 _ready 取走交接旗标（取即清，只消费一次）。
func take_handoff() -> bool:
	var pending := _handoff
	_handoff = false
	return pending

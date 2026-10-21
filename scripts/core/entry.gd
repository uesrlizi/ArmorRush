extends Node2D
## 入口跳板：run/main_scene 指这里，只做一件事——从 RunState 抽第一关
## （只从开局白名单 FIRST_POOL 抽）并立刻跳过去，本场景不显示任何内容。
## 启动页（机甲站桩待命 + 开始提示）照旧由第一关自己的 TitleScreen 负责，
## 所以这里不置交接旗标——第一关照常走启动页，点开始才进战斗。

func _ready() -> void:
	# change_scene_to_file 会释放本场景；deferred 一拍避开装载期。
	_redirect.call_deferred()


func _redirect() -> void:
	get_tree().change_scene_to_file(RunState.start_run())

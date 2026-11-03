extends Enemy
## 悬浮无人机：比步行者更小更脆的飞行单位。
## 出生时从贴地姿态抬到地表上方巡航（BalanceEnemy.DRONE_HOVER_*，上限保证近战够得着），
## 之后只有视觉层正弦浮动；枪臂/射击链路与步行者共用基类。

func _species_max_hp() -> int:
	return BalanceEnemy.DRONE_MAX_HP


func _species_score() -> int:
	return BalanceEnemy.DRONE_SCORE


func _hover_height() -> float:
	return randf_range(BalanceEnemy.DRONE_HOVER_MIN, BalanceEnemy.DRONE_HOVER_MAX)


## 轻浮机体：被命中飘得比步行者更远。
func _knockback_scale() -> float:
	return 1.3

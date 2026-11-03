extends Enemy
## 盾卫：正面挂厚重盾板的步行者。
## 防御力（BalanceEnemy.SHIELD_DEFENSE）把 2 伤子弹吃成 1——"枪打不动"但不完全免疫；
## 近战由 Player 传 ignore_defense 绕盾全额结算，30 HP 恰好任意两刀斩净。

func _species_max_hp() -> int:
	return BalanceEnemy.SHIELD_MAX_HP


func _species_score() -> int:
	return BalanceEnemy.SHIELD_SCORE


## 盾卫拖着厚重盾板：击退明显小于步行者。
func _knockback_scale() -> float:
	return 0.5


func _defense() -> int:
	return BalanceEnemy.SHIELD_DEFENSE

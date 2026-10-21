class_name GroundSparks
extends CPUParticles2D
## 地面滑行火花：机体贴地高速滑行时从脚底向后上方刮出的火星（AC6 式擦地）。
## 发射朝本节点 +X（=滑行后方），由 Player 按朝向镜像；粒子全局坐标，
## 拖尾留在滑行身后，重力让它下坠弹跳。
## 密度固定，喷速跟滑速走（CPUParticles2D 没有 amount_ratio，那是 GPUParticles 专属）。

const LAND_KICK_TIME := 0.16 # 重落地踢火花的额外喷射时长（秒）


func set_slide(active: bool, speed_ratio: float) -> void:
	emitting = active
	if active:
		var r := clampf(speed_ratio, 0.3, 1.25) # 滑得越快火星越急；突进可超 1
		initial_velocity_min = 140.0 * r
		initial_velocity_max = 340.0 * r

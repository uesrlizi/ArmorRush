class_name Platforms
## 运行平台判定。全项目"移动端？"分支统一走这里，别再直接查 OS.has_feature。
## 只查 OS.has_feature("mobile") 对网页版不成立：mobile 是编译期标签，
## Web 导出上恒为 false（官方文档明确），网页端须按浏览器 UA 运行时
## 下发的 web_android / web_ios 标签判；原生端两者本就不命中，归 mobile 管。

static func is_mobile() -> bool:
	return (
		OS.has_feature("mobile")
		or OS.has_feature("web_android")
		or OS.has_feature("web_ios")
	)


static func is_web() -> bool:
	return OS.has_feature("web")

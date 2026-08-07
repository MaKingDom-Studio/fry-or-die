## Вино: увеличивает таймер раунда.
class_name SpiceWine
extends SpiceModel

@export var bonus_seconds := 2.0


func modify_timer_duration(_player: Player, seconds: float) -> float:
	return seconds + bonus_seconds

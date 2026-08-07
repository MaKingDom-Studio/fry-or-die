## Крутой перец: врагу нужно набрать на 1 звезду больше, чтобы игрок проиграл.
class_name SpiceToughPepper
extends SpiceModel

@export var extra_defeat_stars := 1


func modify_defeat_star_target(_player: Player, target: int) -> int:
	return target + extra_defeat_stars

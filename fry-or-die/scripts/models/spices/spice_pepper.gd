## Перец: даёт на 1 ингредиент больше в корзине (и, значит, в высыпании).
class_name SpicePepper
extends SpiceModel

@export var extra_ingredients := 1


func modify_basket_size(_player: Player, size: int) -> int:
	return size + extra_ingredients

## Масло: повышает ценность продуктов игрока на 25%.
class_name SpiceOil
extends SpiceModel

@export_range(0.0, 1.0) var bonus := 0.25


func modify_ingredient_points(_player: Player, _ingredient: IngredientModel,
		points: float, on_player_field: bool) -> float:
	if on_player_field and points > 0.0:
		return points * (1.0 + bonus)
	return points

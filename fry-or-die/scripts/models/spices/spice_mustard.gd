## Горчица: увеличивает силу негативных ингредиентов на поле врага.
class_name SpiceMustard
extends SpiceModel

## На сколько сильнее негативные ингредиенты на враге (0.5 = +50%).
@export var strength := 0.5


func modify_ingredient_points(_player: Player, _ingredient: IngredientModel,
		points: float, on_player_field: bool) -> float:
	if not on_player_field and points < 0.0:
		return points * (1.0 + strength)
	return points

## Газовая горелка: после таймера позволяет убрать один любой ингредиент
## где угодно на поле (в том числе вечный) — или просто пропустить.
class_name ToolBurner
extends ToolModel


func can_burn_after_timer() -> bool:
	return true

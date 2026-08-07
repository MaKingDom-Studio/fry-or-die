## Одна разрешённая единица высыпания: какой ингредиент и в какой участок
## стола он падает.
##
## Ходы врага ([EnemyMove] → [EnemySpawnGroup]) и корзина игрока
## разворачиваются в плоский список [SpawnRequest], который режим боя
## ([code]gm_combat[/code]) раскидывает по столу. Размещение берётся из
## [enum EnemySpawnGroup.Placement].
class_name SpawnRequest
extends RefCounted

var model: IngredientModel
var placement: EnemySpawnGroup.Placement


func _init(spawn_model: IngredientModel,
		spawn_placement: EnemySpawnGroup.Placement = EnemySpawnGroup.Placement.ENEMY) -> void:
	model = spawn_model
	placement = spawn_placement

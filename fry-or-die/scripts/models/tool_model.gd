## Инструмент. Приобретается у торговцев так же, как ингредиенты.
##
## Если у игрока есть готовые (не на кулдауне) инструменты, перед началом
## раунда ему даётся выбор, какой использовать ([method PlayerRoundState.select_tool]).
## Инструмент действует ровно один раунд, после чего выбор происходит заново.
## Выбранный инструмент не пропадает из инвентаря, но может уйти в кулдаун —
## его длительность настраивается здесь и в [GameConfig].
##
## Конкретные инструменты — наследники этого ресурса (scripts/models/tools/)
## с переопределёнными способностями.
class_name ToolModel
extends Resource

@export var id: StringName
@export var display_name := ""
@export_multiline var description := ""
@export var texture: Texture2D
## Цвет значка инструмента в HUD, пока нет изображения.
@export var color := Color.WHITE

## Кулдаун (в раундах) после использования.
## -1 — взять [member GameConfig.default_tool_cooldown]; 0 — без кулдауна.
## Кулдаун N означает, что инструмент пропустит N раундов.
@export var cooldown_rounds: int = -1


## Итоговый кулдаун с учётом настроек конфига.
func get_cooldown(config: GameConfig) -> int:
	if not config.tool_cooldown_enabled:
		return 0
	if cooldown_rounds < 0:
		return config.default_tool_cooldown
	return cooldown_rounds


## Вызывается в начале раунда, в котором инструмент выбран активным.
func on_round_start(_player: Player) -> void:
	pass


## Вызывается в конце раунда, в котором инструмент был активен,
## непосредственно перед уходом в кулдаун.
func on_round_end(_player: Player) -> void:
	pass


## Хуки-модификаторы и способности. Действуют только пока инструмент активен
## (один раунд).

func modify_basket_size(_player: Player, size: int) -> int:
	return size


## Радиус группового захвата (сито). 0 — обычный захват одного ингредиента.
func get_grab_radius() -> float:
	return 0.0


## Можно ли трогать ингредиенты в области врага (удочка).
func can_touch_enemy_area() -> bool:
	return false


## Способность тесака: после выбора инструмента лезвие падает на середину
## стола, подбрасывает всё вокруг, а накрытое собой увозит на половину игрока.
## null — у инструмента такой способности нет. Как выглядит удар и насколько
## далеко едет задетое — в самой способности ([CleaverAbility]).
func get_cleaver_ability() -> CleaverAbility:
	return null


## Способность крюка (удочка): после выбора инструмента крюк вылетает
## из-за края стола со стороны игрока, цепляет самое далёкое от него полезное
## и тянет к нему. null — у инструмента такой способности нет. Сколько
## ингредиентов утянет и как летит крюк — в самой способности ([HookAbility]).
func get_hook_ability() -> HookAbility:
	return null


## Можно ли после таймера убрать один любой ингредиент с поля (горелка).
func can_burn_after_timer() -> bool:
	return false


## Способность щипцов: после выбора инструмента они прилетают на стол и
## утаскивают ингредиенты с половины врага на половину игрока. null —
## у инструмента такой способности нет. Сколько ингредиентов утащат и как
## они летят — в самой способности ([TongsAbility]).
func get_tongs_ability() -> TongsAbility:
	return null

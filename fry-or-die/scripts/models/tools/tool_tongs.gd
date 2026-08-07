## Щипцы игрока: после выбора инструмента прилетают на стол и утаскивают
## самый ценный ингредиент с половины врага на половину игрока.
##
## Зеркало способности минибосса «Tongie» ([TongsAbility]): полёт рисует тот
## же узел [TongsNode], только щипцы приходят слева снизу и добыча едет не к
## врагу, а к игроку. Сколько ингредиентов утащат за раунд — в самой
## способности ([member TongsAbility.steal_count]).
class_name ToolTongs
extends ToolModel

## Изображения губок, траектория полёта и число целей за раунд.
## Настраивается в _Game/Data/Combat/Tools/da_tool_tongs.tres.
@export var ability: TongsAbility


func get_tongs_ability() -> TongsAbility:
	return ability

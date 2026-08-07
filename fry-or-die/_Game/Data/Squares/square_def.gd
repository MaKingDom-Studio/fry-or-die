class_name SquareDef
extends Resource

## Тип куба (аналог DataAsset юнита из UE): диапазон размера, плотность, цвет.
## Новый вид куба = новый da_square_*.tres, код менять не нужно.

@export var display_name := ""

@export_group("Size")
@export var min_side := 36.0
@export var max_side := 72.0

@export_group("Physics")
@export var density := 1.0          # масса = density * (side / 36)^2

@export_group("Look")
## Если выключено, цвет подбирается автоматически по весу (белый -> оранжевый).
@export var use_custom_color := false
@export var custom_color := Color.WHITE

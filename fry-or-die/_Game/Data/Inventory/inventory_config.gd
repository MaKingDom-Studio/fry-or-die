class_name InventoryConfig
extends Resource

## Стартовый инвентарь кубов: из этих стеков происходит спавн на арену.
## Настраивается в da_inventory.tres; состав меняется без правки кода.

@export var entries: Array[InventoryEntry] = []

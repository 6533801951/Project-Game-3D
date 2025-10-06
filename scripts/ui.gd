extends CanvasLayer

@onready var hp_bar1 = $Control/HpBar1
@onready var hp_bar2 = $Control/HpBar2
@onready var sta_bar1 = $Control/StaminaBar1
@onready var sta_bar2 = $Control/StaminaBar2
@onready var item_count_label = $Control/ItemUI/count
@onready var boss_health_bar = $BossHealthBar

var max_health: float = 100
var max_stamina: float = 100
var item_count: int = 5

func _ready():
	boss_health_bar.max_value = 1000
	boss_health_bar.value = 1000
	update_item_count()
	
func set_health(value: float):
	value = clamp(value, 0, max_health)

	if value <= 50:
		hp_bar1.value = value
		hp_bar2.value = 0
	else:
		hp_bar1.value = 50
		hp_bar2.value = value - 50

func set_stamina(value:float):
	value = clamp(value,0,max_stamina)
	if value <= 50:
		sta_bar1.value = value
		sta_bar2.value = 0
	else:
		sta_bar1.value = 50
		sta_bar2.value = value - 50

func update_item_count():
	item_count_label.text = str(item_count)

func use_item() -> bool:
	if item_count > 0:
		item_count -= 1
		update_item_count()
		return true
	return false

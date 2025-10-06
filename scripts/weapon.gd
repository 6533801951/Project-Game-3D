extends Node3D

@export var damage: int = 15
@onready var hitbox: Area3D = $Area3D

func _ready():
	hitbox.monitoring = false
	hitbox.body_entered.connect(_on_body_entered)

func _on_body_entered(body):
	if hitbox.monitoring and body.is_in_group("enemy"):
		if body.has_method("take_damage"):
			body.take_damage(damage)

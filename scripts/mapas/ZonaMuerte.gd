extends Area2D
class_name ZonaMuerte

# Conecta senal de colision y configura capas
func _ready() -> void:
	body_entered.connect(_on_body_entered)
	collision_layer = 0
	collision_mask = 1

# Aplica dano letal a personajes que entren en la zona
func _on_body_entered(body: Node2D) -> void:
	if body.has_method("recibir_dano") and body.has_method("esta_vivo"):
		if body.esta_vivo():
			body.recibir_dano(999)

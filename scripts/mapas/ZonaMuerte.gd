extends Area2D
class_name ZonaMuerte

## Área que elimina personajes que caen fuera del mapa

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	collision_layer = 0
	collision_mask = 1

func _on_body_entered(body: Node2D) -> void:
	if body.has_method("recibir_dano") and body.has_method("esta_vivo"):
		if body.esta_vivo():
			print("¡Jugador %d cayó al vacío!" % body.player_id)
			body.recibir_dano(999)

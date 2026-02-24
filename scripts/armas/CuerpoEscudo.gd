extends StaticBody2D

# Delega el golpe al escudo padre
func recibir_dano(_cantidad: int = 1, _posicion_atacante: Vector2 = Vector2.INF) -> void:
	var escudo = get_parent()
	if escudo and escudo.has_method("bloquear_golpe"):
		escudo.bloquear_golpe()

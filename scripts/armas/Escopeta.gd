extends ArmaBase

## Escopeta que dispara múltiples balas en abanico

# === CONSTANTES ===
const BALAS_POR_DISPARO: int = 3  # ← Cambiado a 3 como querías
const ANGULO_DISPERSION: float = 10.0  # Grados de separación entre balas

# === SOBRESCRITURA DE MÉTODO DISPARAR ===

## Dispara múltiples balas en abanico
func disparar() -> void:
	if not bala_scene:
		push_warning("Escopeta: bala_scene no asignado")
		return
	
	# Calcular el ángulo base del arma
	var angulo_base := global_rotation
	
	# Calcular ángulos para cada bala
	# Si son 3 balas: -20°, 0°, +20°
	# Si son 5 balas: -40°, -20°, 0°, +20°, +40°
	var angulo_paso := deg_to_rad(ANGULO_DISPERSION)
	var mitad := (BALAS_POR_DISPARO - 1) / 2.0
	
	# Crear múltiples balas
	for i in range(BALAS_POR_DISPARO):
		var bala := bala_scene.instantiate() as Area2D
		if not bala:
			continue
		
		# Configurar posición base usando el método heredado
		_configurar_bala(bala)
		
		# Calcular el ángulo específico de esta bala
		# Ejemplo para 3 balas: i=0 → -1, i=1 → 0, i=2 → +1
		var offset_angulo := (i - mitad) * angulo_paso
		bala.global_rotation = angulo_base + offset_angulo
		
		# Añadir al mundo usando el método heredado
		_generar_bala(bala)
	
	# Usar el sistema de cooldown heredado de ArmaBase
	_iniciar_cooldown_disparo()
	arma_disparada.emit()

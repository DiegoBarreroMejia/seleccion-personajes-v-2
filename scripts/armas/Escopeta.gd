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

	if not _tiene_municion():
		return

	# Calcular el ángulo base del arma
	var angulo_base := global_rotation

	# Calcular ángulos para cada bala
	var angulo_paso := deg_to_rad(ANGULO_DISPERSION)
	var mitad := (BALAS_POR_DISPARO - 1) / 2.0

	# Crear múltiples balas
	for i in range(BALAS_POR_DISPARO):
		var bala := bala_scene.instantiate() as Area2D
		if not bala:
			continue

		_configurar_bala(bala)

		var offset_angulo := (i - mitad) * angulo_paso
		bala.global_rotation = angulo_base + offset_angulo

		_generar_bala(bala)

	# Consumir 1 bala por disparo de escopeta (un cartucho = múltiples perdigones)
	_consumir_bala()

	_iniciar_cooldown_disparo()
	arma_disparada.emit()

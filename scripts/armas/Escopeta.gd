extends ArmaBase

const BALAS_POR_DISPARO: int = 3
const ANGULO_DISPERSION: float = 10.0

# Dispara multiples balas en abanico
func disparar() -> void:
	if not bala_scene:
		push_warning("Escopeta: bala_scene no asignado")
		return

	if not _tiene_municion():
		return

	var angulo_base := global_rotation
	var angulo_paso := deg_to_rad(ANGULO_DISPERSION)
	var mitad := (BALAS_POR_DISPARO - 1) / 2.0

	for i in range(BALAS_POR_DISPARO):
		var bala := bala_scene.instantiate() as Area2D
		if not bala:
			continue

		_configurar_bala(bala)

		var offset_angulo := (i - mitad) * angulo_paso
		bala.global_rotation = angulo_base + offset_angulo

		_generar_bala(bala)

	_consumir_bala()
	_iniciar_cooldown_disparo()

	if sfx_disparo and _sfx_player:
		_sfx_player.stream = sfx_disparo
		_sfx_player.play()

	arma_disparada.emit()

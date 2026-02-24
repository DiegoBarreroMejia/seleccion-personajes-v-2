extends ArmaBase

# Dispara y se autodestruye si no queda municion
func disparar() -> void:
	var sonido_stream: AudioStream = sfx_disparo

	super.disparar()

	if not _tiene_municion():
		if sonido_stream:
			var sfx := AudioStreamPlayer2D.new()
			sfx.stream = sonido_stream
			sfx.bus = "SFX"
			sfx.max_distance = 800.0
			sfx.global_position = global_position
			get_tree().root.add_child(sfx)
			sfx.play()
			sfx.finished.connect(sfx.queue_free)

		var dueno := _obtener_dueno_personaje()
		if dueno and dueno.has_method("liberar_arma"):
			dueno.liberar_arma()
		queue_free()

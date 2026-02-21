extends ArmaBase

## Granada de un solo uso con temporizador de explosión
##
## Al pulsar disparo se quita la anilla (cambio visual) y empieza un
## temporizador. Al terminar, la granada explota y daña a TODOS los
## personajes dentro del radio, incluido el propio lanzador.
## El jugador puede lanzarla con el sistema de soltar/lanzar normal.

# === CONSTANTES — SPRITES ===
const SPRITE_ENTERA: Texture2D = preload("res://assets/sprites/armas/granada/Granada_entera.png")
const SPRITE_CUERPO: Texture2D = preload("res://assets/sprites/armas/granada/Granada_cuerpo.png")
const SPRITE_ANILLA: Texture2D = preload("res://assets/sprites/armas/granada/Granada_ibilla.png")

# === CONSTANTES — EXPLOSIÓN ===
const SFX_EXPLOSION: AudioStream = preload("res://assets/sonidos/Armas/sonido_grenade_explosion.ogg")
const SPRITES_EXPLOSION: Array[Texture2D] = [
	preload("res://assets/sprites/vfx/explosiones/explosion1.png"),
	preload("res://assets/sprites/vfx/explosiones/explosion2.png"),
	preload("res://assets/sprites/vfx/explosiones/explosion3.png"),
	preload("res://assets/sprites/vfx/explosiones/explosion4.png"),
	preload("res://assets/sprites/vfx/explosiones/explosion5.png"),
	preload("res://assets/sprites/vfx/explosiones/explosion6.png"),
	preload("res://assets/sprites/vfx/explosiones/explosion7.png"),
	preload("res://assets/sprites/vfx/explosiones/explosion8.png"),
]

# === CONSTANTES — ANILLA ===
const ANILLA_CAIDA_DISTANCIA: float = 50.0
const ANILLA_CAIDA_DURACION: float = 0.5

# === CONSTANTES — VFX ===
const EXPLOSION_FPS: float = 12.0

# === VARIABLES EXPORTADAS ===
@export_group("Granada")
## Segundos antes de que la granada explote tras quitar la anilla.
@export var tiempo_explosion: float = 5.0
## Daño que inflige la explosión a cada personaje en el radio.
@export var dano_explosion: int = 3

# === VARIABLES PRIVADAS ===
var _anilla_quitada: bool = false
var _temporizador_explosion: Timer = null
var _sprite_nodo: Sprite2D = null
var _area_explosion: Area2D = null

# === CICLO DE VIDA ===

func _ready() -> void:
	super._ready()

	# Referencias a nodos
	_sprite_nodo = $Sprite2D if has_node("Sprite2D") else null
	_area_explosion = $AreaExplosion if has_node("AreaExplosion") else null

	# Desactivar área de explosión hasta que sea necesaria
	if _area_explosion:
		_area_explosion.monitoring = false

	# Crear temporizador de explosión
	_temporizador_explosion = Timer.new()
	_temporizador_explosion.one_shot = true
	_temporizador_explosion.timeout.connect(_explotar)
	add_child(_temporizador_explosion)

# === SISTEMA DE DISPARO (QUITAR ANILLA) ===

func _verificar_input_disparo() -> void:
	# Si ya se quitó la anilla, no hacer nada más
	if _anilla_quitada:
		return

	var controles := _obtener_controles_dueno()
	if controles.is_empty():
		return

	if Input.is_action_just_pressed(controles["shoot"]) and _puede_disparar:
		disparar()

func disparar() -> void:
	if _anilla_quitada:
		return

	_anilla_quitada = true

	# Cambiar sprite a granada sin anilla
	if _sprite_nodo:
		_sprite_nodo.texture = SPRITE_CUERPO

	# Crear efecto visual de la anilla cayendo
	_crear_anilla_visual()

	# Iniciar temporizador de explosión
	_temporizador_explosion.start(tiempo_explosion)

	# Bloquear disparos futuros
	_puede_disparar = false

	arma_disparada.emit()

# === EFECTO VISUAL — ANILLA ===

func _crear_anilla_visual() -> void:
	var anilla := Sprite2D.new()
	anilla.texture = SPRITE_ANILLA
	anilla.global_position = global_position

	# Copiar escala del sprite de la granada para que la anilla tenga tamaño coherente
	if _sprite_nodo:
		anilla.scale = _sprite_nodo.scale

	get_tree().root.add_child(anilla)

	# Animar: caída + desvanecimiento
	var tween := anilla.create_tween()
	tween.set_parallel(true)
	tween.tween_property(anilla, "position:y", anilla.position.y + ANILLA_CAIDA_DISTANCIA, ANILLA_CAIDA_DURACION)
	tween.tween_property(anilla, "modulate:a", 0.0, ANILLA_CAIDA_DURACION)
	tween.set_parallel(false)
	tween.tween_callback(anilla.queue_free)

# === EXPLOSIÓN ===

func _explotar() -> void:
	# Guardar posición antes de cualquier cambio de jerarquía
	var pos_explosion := global_position

	# Si está en la mano del jugador, liberar primero
	if _esta_recogida:
		var dueno := _obtener_dueno_personaje()
		if dueno and dueno.has_method("liberar_arma"):
			dueno.liberar_arma()

	# --- Detectar víctimas con consulta directa al espacio de física ---
	var radio := _obtener_radio_explosion()
	var space_state := get_world_2d().direct_space_state
	if space_state:
		var circulo := CircleShape2D.new()
		circulo.radius = radio

		var query := PhysicsShapeQueryParameters2D.new()
		query.shape = circulo
		query.transform = Transform2D(0, pos_explosion)
		query.collision_mask = 1  # Layer 1 = jugadores
		query.collide_with_bodies = true

		var resultados := space_state.intersect_shape(query)
		for resultado in resultados:
			var cuerpo = resultado["collider"]
			if cuerpo is CharacterBody2D and cuerpo.is_in_group("jugadores"):
				if cuerpo.has_method("recibir_dano"):
					cuerpo.recibir_dano(dano_explosion)

	# --- Efecto visual de explosión ---
	_crear_efecto_explosion(pos_explosion)

	# --- Sonido de explosión ---
	_crear_sonido_explosion(pos_explosion)

	# --- Destruir granada ---
	queue_free()

func _obtener_radio_explosion() -> float:
	## Calcula el radio efectivo de explosión desde el AreaExplosion del editor.
	## Tiene en cuenta la escala del Area2D y del CollisionShape2D.
	if _area_explosion:
		var shape_node := _area_explosion.get_node_or_null("CollisionShape2D") as CollisionShape2D
		if shape_node and shape_node.shape is CircleShape2D:
			var circulo := shape_node.shape as CircleShape2D
			return circulo.radius * absf(shape_node.scale.x) * absf(_area_explosion.scale.x)
	return 80.0  # Valor por defecto si no se encuentra el nodo

func _crear_efecto_explosion(pos: Vector2) -> void:
	# Crear SpriteFrames con los 8 frames de explosión
	var sprite_frames := SpriteFrames.new()
	sprite_frames.remove_animation(&"default")
	sprite_frames.add_animation(&"explosion")
	sprite_frames.set_animation_speed(&"explosion", EXPLOSION_FPS)
	sprite_frames.set_animation_loop(&"explosion", false)

	for textura in SPRITES_EXPLOSION:
		sprite_frames.add_frame(&"explosion", textura)

	# Crear AnimatedSprite2D temporal
	var efecto := AnimatedSprite2D.new()
	efecto.sprite_frames = sprite_frames
	efecto.global_position = pos
	efecto.z_index = 10  # Por encima de todo

	# Escalar para que cubra bien el área de explosión
	var radio := _obtener_radio_explosion()
	var escala_explosion := radio / 40.0  # 40px es aprox. el radio visual del sprite base
	efecto.scale = Vector2(escala_explosion, escala_explosion)

	get_tree().root.add_child(efecto)
	efecto.play(&"explosion")
	efecto.animation_finished.connect(efecto.queue_free)

func _crear_sonido_explosion(pos: Vector2) -> void:
	var audio := AudioStreamPlayer2D.new()
	audio.stream = SFX_EXPLOSION
	audio.bus = "SFX"
	audio.max_distance = 800.0
	audio.global_position = pos

	get_tree().root.add_child(audio)
	audio.play()
	audio.finished.connect(audio.queue_free)

extends ArmaBase

const SPRITE_ENTERA: Texture2D = preload("res://assets/sprites/armas/granada/Granada_entera.png")
const SPRITE_CUERPO: Texture2D = preload("res://assets/sprites/armas/granada/Granada_cuerpo.png")
const SPRITE_ANILLA: Texture2D = preload("res://assets/sprites/armas/granada/Granada_ibilla.png")

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

const ANILLA_CAIDA_DISTANCIA: float = 50.0
const ANILLA_CAIDA_DURACION: float = 0.5
const EXPLOSION_FPS: float = 12.0

@export_group("Granada")
@export var tiempo_explosion: float = 5.0
@export var dano_explosion: int = 3

var _anilla_quitada: bool = false
var _temporizador_explosion: Timer = null
var _sprite_nodo: Sprite2D = null
var _area_explosion: Area2D = null

# Configura nodos, area de explosion y temporizador
func _ready() -> void:
	super._ready()

	_sprite_nodo = $Sprite2D if has_node("Sprite2D") else null
	_area_explosion = $AreaExplosion if has_node("AreaExplosion") else null

	if _area_explosion:
		_area_explosion.monitoring = false

	_temporizador_explosion = Timer.new()
	_temporizador_explosion.one_shot = true
	_temporizador_explosion.timeout.connect(_explotar)
	add_child(_temporizador_explosion)

# Solo permite quitar anilla una vez
func _verificar_input_disparo() -> void:
	if _anilla_quitada:
		return

	var controles := _obtener_controles_dueno()
	if controles.is_empty():
		return

	if Input.is_action_just_pressed(controles["shoot"]) and _puede_disparar:
		disparar()

# Quita la anilla e inicia temporizador de explosion
func disparar() -> void:
	if _anilla_quitada:
		return

	_anilla_quitada = true

	if _sprite_nodo:
		_sprite_nodo.texture = SPRITE_CUERPO

	_crear_anilla_visual()
	_temporizador_explosion.start(tiempo_explosion)
	_puede_disparar = false

	arma_disparada.emit()

# Crea el efecto visual de la anilla cayendo
func _crear_anilla_visual() -> void:
	var anilla := Sprite2D.new()
	anilla.texture = SPRITE_ANILLA
	anilla.global_position = global_position

	if _sprite_nodo:
		anilla.scale = _sprite_nodo.scale

	get_tree().root.add_child(anilla)

	var tween := anilla.create_tween()
	tween.set_parallel(true)
	tween.tween_property(anilla, "position:y", anilla.position.y + ANILLA_CAIDA_DISTANCIA, ANILLA_CAIDA_DURACION)
	tween.tween_property(anilla, "modulate:a", 0.0, ANILLA_CAIDA_DURACION)
	tween.set_parallel(false)
	tween.tween_callback(anilla.queue_free)

# Explota danando a todos los jugadores en el radio
func _explotar() -> void:
	var pos_explosion := global_position

	if _esta_recogida:
		var dueno := _obtener_dueno_personaje()
		if dueno and dueno.has_method("liberar_arma"):
			dueno.liberar_arma()

	var radio := _obtener_radio_explosion()
	var space_state := get_world_2d().direct_space_state
	if space_state:
		var circulo := CircleShape2D.new()
		circulo.radius = radio

		var query := PhysicsShapeQueryParameters2D.new()
		query.shape = circulo
		query.transform = Transform2D(0, pos_explosion)
		query.collision_mask = 1
		query.collide_with_bodies = true

		var resultados := space_state.intersect_shape(query)
		for resultado in resultados:
			var cuerpo = resultado["collider"]
			if cuerpo is CharacterBody2D and cuerpo.is_in_group("jugadores"):
				if cuerpo.has_method("recibir_dano"):
					cuerpo.recibir_dano(dano_explosion, pos_explosion)

	_crear_efecto_explosion(pos_explosion)
	_crear_sonido_explosion(pos_explosion)
	queue_free()

# Calcula el radio de explosion desde el AreaExplosion
func _obtener_radio_explosion() -> float:
	if _area_explosion:
		var shape_node := _area_explosion.get_node_or_null("CollisionShape2D") as CollisionShape2D
		if shape_node and shape_node.shape is CircleShape2D:
			var circulo := shape_node.shape as CircleShape2D
			return circulo.radius * absf(shape_node.scale.x) * absf(_area_explosion.scale.x)
	return 80.0

# Crea el efecto visual de explosion animado
func _crear_efecto_explosion(pos: Vector2) -> void:
	var sprite_frames := SpriteFrames.new()
	sprite_frames.remove_animation(&"default")
	sprite_frames.add_animation(&"explosion")
	sprite_frames.set_animation_speed(&"explosion", EXPLOSION_FPS)
	sprite_frames.set_animation_loop(&"explosion", false)

	for textura in SPRITES_EXPLOSION:
		sprite_frames.add_frame(&"explosion", textura)

	var efecto := AnimatedSprite2D.new()
	efecto.sprite_frames = sprite_frames
	efecto.global_position = pos
	efecto.z_index = 10

	var radio := _obtener_radio_explosion()
	var escala_explosion := radio / 16.0
	efecto.scale = Vector2(escala_explosion, escala_explosion)

	get_tree().root.add_child(efecto)
	efecto.play(&"explosion")
	efecto.animation_finished.connect(efecto.queue_free)

# Crea el sonido de explosion temporal en el root
func _crear_sonido_explosion(pos: Vector2) -> void:
	var audio := AudioStreamPlayer2D.new()
	audio.stream = SFX_EXPLOSION
	audio.bus = "SFX"
	audio.max_distance = 800.0
	audio.global_position = pos

	get_tree().root.add_child(audio)
	audio.play()
	audio.finished.connect(audio.queue_free)

extends StaticBody2D

const IDLE_TEXTURE: Texture2D = preload("res://assets/sprites/partida/barril_explosivo/barril_quieto.png")
const SFX_EXPLOSION: AudioStream = preload("res://assets/sonidos/Armas/sonido_grenade_explosion.ogg")

const EXPLOSION_FPS: float = 12.0
const EXPLOSION_ANCHO: int = 95
const EXPLOSION_ALTO: int = 150

const OFFSET_IDLE := Vector2(0, -24)
const OFFSET_EXPLOSION := Vector2(0, -60)
const ESCALA_EXPLOSION := Vector2(2.5, 2.5)

@export var dano_explosion: int = 1

var _explotado: bool = false

# Crea las animaciones idle y explosion
func _ready() -> void:
	_crear_animaciones()

# Configura sprite frames con idle y explosion
func _crear_animaciones() -> void:
	var sprite_frames := SpriteFrames.new()
	sprite_frames.remove_animation(&"default")

	sprite_frames.add_animation(&"idle")
	sprite_frames.set_animation_speed(&"idle", 1.0)
	sprite_frames.set_animation_loop(&"idle", true)
	sprite_frames.add_frame(&"idle", IDLE_TEXTURE)

	sprite_frames.add_animation(&"explosion")
	sprite_frames.set_animation_speed(&"explosion", EXPLOSION_FPS)
	sprite_frames.set_animation_loop(&"explosion", false)
	for i in range(1, 13):
		var tex := load("res://assets/sprites/partida/barril_explosivo/barril_explosivo_%d.png" % i)
		sprite_frames.add_frame(&"explosion", tex)

	$AnimatedSprite2D.sprite_frames = sprite_frames
	$AnimatedSprite2D.offset = OFFSET_IDLE
	$AnimatedSprite2D.play(&"idle")

# Recibe dano y explota
func recibir_dano(_cantidad: int = 1, _posicion_atacante: Vector2 = Vector2.INF) -> void:
	if _explotado:
		return
	_explotar()

# Ejecuta la explosion con dano en area
func _explotar() -> void:
	_explotado = true

	collision_layer = 0
	collision_mask = 0

	$AnimatedSprite2D.scale = ESCALA_EXPLOSION
	$AnimatedSprite2D.offset = OFFSET_EXPLOSION
	$AnimatedSprite2D.play(&"explosion")

	var pos_explosion := global_position
	var escala_sprite: Vector2 = $AnimatedSprite2D.scale
	var space_state := get_world_2d().direct_space_state
	if space_state:
		var rect := RectangleShape2D.new()
		rect.size = Vector2(EXPLOSION_ANCHO * escala_sprite.x, EXPLOSION_ALTO * escala_sprite.y)

		var query := PhysicsShapeQueryParameters2D.new()
		query.shape = rect
		var offset_mundo: Vector2 = OFFSET_EXPLOSION * escala_sprite
		query.transform = Transform2D(0, pos_explosion + offset_mundo)
		query.collision_mask = 1
		query.collide_with_bodies = true

		var resultados := space_state.intersect_shape(query)
		for resultado in resultados:
			var cuerpo = resultado["collider"]
			if cuerpo == self:
				continue
			if cuerpo.has_method("recibir_dano"):
				cuerpo.recibir_dano(dano_explosion, pos_explosion)

	_crear_sonido_explosion(pos_explosion)

	await $AnimatedSprite2D.animation_finished
	queue_free()

# Crea sonido de explosion temporal en el root
func _crear_sonido_explosion(pos: Vector2) -> void:
	var audio := AudioStreamPlayer2D.new()
	audio.stream = SFX_EXPLOSION
	audio.bus = "SFX"
	audio.max_distance = 800.0
	audio.global_position = pos

	get_tree().root.add_child(audio)
	audio.play()
	audio.finished.connect(audio.queue_free)

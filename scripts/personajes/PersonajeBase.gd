extends CharacterBody2D
class_name PersonajeBase

signal vida_cambiada(nueva_vida: int)
signal murio(id_jugador: int)
signal recibio_dano(cantidad: int)
signal arma_equipada(arma: Node2D)
signal arma_desequipada()

const VELOCIDAD_DEFECTO: float = 300.0
const FUERZA_SALTO_DEFECTO: float = -500.0
const DISTANCIA_MANO: float = 20.0

const SPRITES_MUERTE: Array[Texture2D] = [
	preload("res://assets/sprites/vfx/efecto_muerte/FX001_01.png"),
	preload("res://assets/sprites/vfx/efecto_muerte/FX001_02.png"),
	preload("res://assets/sprites/vfx/efecto_muerte/FX001_03.png"),
	preload("res://assets/sprites/vfx/efecto_muerte/FX001_04.png"),
	preload("res://assets/sprites/vfx/efecto_muerte/FX001_05.png"),
]
const MUERTE_FPS: float = 10.0

const SPRITES_SANGRE: Array[Texture2D] = [
	preload("res://assets/sprites/partida/sangre_daño/1_0.png"),
	preload("res://assets/sprites/partida/sangre_daño/1_1.png"),
	preload("res://assets/sprites/partida/sangre_daño/1_2.png"),
	preload("res://assets/sprites/partida/sangre_daño/1_3.png"),
	preload("res://assets/sprites/partida/sangre_daño/1_4.png"),
	preload("res://assets/sprites/partida/sangre_daño/1_5.png"),
	preload("res://assets/sprites/partida/sangre_daño/1_6.png"),
	preload("res://assets/sprites/partida/sangre_daño/1_7.png"),
	preload("res://assets/sprites/partida/sangre_daño/1_8.png"),
	preload("res://assets/sprites/partida/sangre_daño/1_9.png"),
	preload("res://assets/sprites/partida/sangre_daño/1_10.png"),
	preload("res://assets/sprites/partida/sangre_daño/1_11.png"),
	preload("res://assets/sprites/partida/sangre_daño/1_12.png"),
	preload("res://assets/sprites/partida/sangre_daño/1_13.png"),
	preload("res://assets/sprites/partida/sangre_daño/1_14.png"),
	preload("res://assets/sprites/partida/sangre_daño/1_15.png"),
	preload("res://assets/sprites/partida/sangre_daño/1_16.png"),
	preload("res://assets/sprites/partida/sangre_daño/1_17.png"),
	preload("res://assets/sprites/partida/sangre_daño/1_18.png"),
	preload("res://assets/sprites/partida/sangre_daño/1_19.png"),
	preload("res://assets/sprites/partida/sangre_daño/1_20.png"),
	preload("res://assets/sprites/partida/sangre_daño/1_21.png"),
	preload("res://assets/sprites/partida/sangre_daño/1_22.png"),
	preload("res://assets/sprites/partida/sangre_daño/1_23.png"),
	preload("res://assets/sprites/partida/sangre_daño/1_24.png"),
	preload("res://assets/sprites/partida/sangre_daño/1_25.png"),
	preload("res://assets/sprites/partida/sangre_daño/1_26.png"),
	preload("res://assets/sprites/partida/sangre_daño/1_27.png"),
	preload("res://assets/sprites/partida/sangre_daño/1_28.png"),
	preload("res://assets/sprites/partida/sangre_daño/1_29.png"),
]
const SANGRE_FPS: float = 24.0

const SONIDOS_PASOS: Array[AudioStream] = [
	preload("res://assets/sonidos/partida/sonido_caminar1.ogg"),
	preload("res://assets/sonidos/partida/sonido_caminar2.ogg"),
	preload("res://assets/sonidos/partida/sonido_caminar3.ogg"),
	preload("res://assets/sonidos/partida/sonido_caminar4.ogg"),
]

@export_group("Movimiento")
@export var speed: float = VELOCIDAD_DEFECTO
@export var jump_velocity: float = FUERZA_SALTO_DEFECTO

@export_group("Configuración Jugador")
@export_range(1, 2) var player_id: int = 1

var _gravity: float = ProjectSettings.get_setting("physics/2d/default_gravity")
var _controls: Dictionary = {}
var _vida_actual: int = 1:
	set(value):
		_vida_actual = maxi(value, 0)
		vida_cambiada.emit(_vida_actual)
		if _vida_actual <= 0:
			_morir()

var _esta_vivo: bool = true
var bloqueado: bool = false
var _direccion_mirada: int = 1
var _estaba_en_suelo: bool = true
var _arma_actual: Node2D = null
var _accion_consumida_frame: int = -1

@onready var _sprite: Sprite2D = $Sprite if has_node("Sprite") else null
@onready var _mano: Node2D = _buscar_nodo_mano()
@onready var _visuals: Node2D = $Visuals if has_node("Visuals") else null
@onready var _anim_player: AnimationPlayer = $AnimationPlayer if has_node("AnimationPlayer") else null

var _es_articulado: bool = false

var _sfx_pasos_player: AudioStreamPlayer2D = null
var _indice_paso_actual: int = 0
var _cooldown_paso: float = 0.0
const INTERVALO_PASO: float = 0.28

# Inicializa controles, vida, tipo de personaje y sonido de pasos
func _ready() -> void:
	_configurar_controles()
	_vida_actual = Global.vida_maxima
	_detectar_tipo_personaje()
	_validar_nodos()
	_configurar_sfx_pasos()
	add_to_group("jugadores")

	if _anim_player and _anim_player.has_animation("Reposo"):
		_anim_player.play("Reposo")

# Aplica gravedad, movimiento, salto, animacion y pasos cada frame
func _physics_process(delta: float) -> void:
	if not _esta_vivo:
		return

	_aplicar_gravedad(delta)

	if not bloqueado:
		_gestionar_movimiento()
		_gestionar_salto()

	_actualizar_animacion()
	_gestionar_sonido_pasos(delta)
	move_and_slide()

# Obtiene controles del jugador desde Global
func _configurar_controles() -> void:
	_controls = Global.obtener_controles(player_id)
	if _controls.is_empty():
		push_error("PersonajeBase: No se pudieron obtener controles para jugador %d" % player_id)

# Busca el nodo Mano en la escena
func _buscar_nodo_mano() -> Node2D:
	if has_node("Mano"):
		return $Mano
	return null

# Detecta si el personaje usa sistema articulado o sprite
func _detectar_tipo_personaje() -> void:
	_es_articulado = _visuals != null and _sprite == null

# Valida que existan nodos visuales y mano
func _validar_nodos() -> void:
	if not _sprite and not _visuals:
		push_warning("PersonajeBase: Ni 'Sprite' ni 'Visuals' encontrado en %s" % name)
	if not _mano:
		push_warning("PersonajeBase: Nodo 'Mano' no encontrado en %s" % name)

# Crea el reproductor de sonido de pasos
func _configurar_sfx_pasos() -> void:
	_sfx_pasos_player = AudioStreamPlayer2D.new()
	_sfx_pasos_player.bus = "SFX"
	_sfx_pasos_player.max_distance = 800.0
	add_child(_sfx_pasos_player)

# Reproduce sonido de paso al caminar en el suelo con cooldown
func _gestionar_sonido_pasos(delta: float) -> void:
	if not _sfx_pasos_player:
		return

	if _cooldown_paso > 0.0:
		_cooldown_paso -= delta
		return

	if bloqueado or not is_on_floor() or _controls.is_empty():
		return

	var moviendo := Input.is_action_pressed(_controls["left"]) or \
				   Input.is_action_pressed(_controls["right"])
	if not moviendo:
		return

	_sfx_pasos_player.stream = SONIDOS_PASOS[_indice_paso_actual]
	_sfx_pasos_player.play()
	_indice_paso_actual = (_indice_paso_actual + 1) % SONIDOS_PASOS.size()
	_cooldown_paso = INTERVALO_PASO

# Aplica gravedad cuando no esta en el suelo
func _aplicar_gravedad(delta: float) -> void:
	if not is_on_floor():
		velocity.y += _gravity * delta

# Gestiona el salto al pulsar la tecla correspondiente
func _gestionar_salto() -> void:
	if _controls.is_empty():
		return

	if Input.is_action_just_pressed(_controls["jump"]) and is_on_floor():
		velocity.y = jump_velocity

# Gestiona el movimiento horizontal y actualiza la direccion
func _gestionar_movimiento() -> void:
	if _controls.is_empty():
		return

	var direction := Input.get_axis(_controls["left"], _controls["right"])

	if direction != 0:
		velocity.x = direction * speed
		_actualizar_direccion_mirada(direction)
	else:
		velocity.x = move_toward(velocity.x, 0, speed)

# Actualiza la direccion de mirada y voltea el personaje
func _actualizar_direccion_mirada(direccion: float) -> void:
	var nueva_direccion: int = 1 if direccion > 0 else -1

	if nueva_direccion != _direccion_mirada:
		_direccion_mirada = nueva_direccion
		_voltear_personaje()

# Voltea sprite o visuals y la mano segun la direccion
func _voltear_personaje() -> void:
	if _es_articulado:
		if _visuals:
			_visuals.scale.x = abs(_visuals.scale.x) * _direccion_mirada
	else:
		if _sprite:
			_sprite.flip_h = (_direccion_mirada < 0)

	if _mano:
		_mano.position.x = abs(_mano.position.x) * _direccion_mirada
		_mano.scale.x = _direccion_mirada

# Selecciona la animacion segun el estado del personaje
func _actualizar_animacion() -> void:
	if not _anim_player:
		return

	var en_suelo := is_on_floor()

	if not en_suelo:
		if _estaba_en_suelo:
			if _anim_player.has_animation("saltar"):
				_anim_player.play("saltar")
		elif velocity.y > 0 and _anim_player.current_animation == "saltar":
			if _anim_player.has_animation("caer"):
				_anim_player.play("caer")
	else:
		if abs(velocity.x) > 10:
			_reproducir_animacion("correr")
		else:
			_reproducir_animacion("Reposo")

	_estaba_en_suelo = en_suelo

# Reproduce una animacion si existe y no esta ya activa
func _reproducir_animacion(nombre_anim: String) -> void:
	if _anim_player and _anim_player.has_animation(nombre_anim):
		if _anim_player.current_animation != nombre_anim:
			_anim_player.play(nombre_anim)

# Ejecuta la muerte del personaje con efecto visual
func _morir() -> void:
	if not _esta_vivo:
		return

	_esta_vivo = false

	set_physics_process(false)
	collision_layer = 0
	collision_mask = 0

	murio.emit(player_id)

	await _reproducir_animacion_muerte()

	if not is_inside_tree():
		return

	await get_tree().create_timer(0.5).timeout
	queue_free()

# Oculta el personaje y muestra el efecto de muerte animado
func _reproducir_animacion_muerte() -> void:
	var nodo_visual: Node2D = _sprite if _sprite else _visuals
	if nodo_visual:
		nodo_visual.visible = false

	if not is_inside_tree():
		return

	var current_scene := get_tree().current_scene
	if not current_scene:
		push_warning("PersonajeBase: current_scene es null, no se puede mostrar efecto de muerte")
		return

	var sprite_frames := SpriteFrames.new()
	sprite_frames.remove_animation(&"default")
	sprite_frames.add_animation(&"muerte")
	sprite_frames.set_animation_speed(&"muerte", MUERTE_FPS)
	sprite_frames.set_animation_loop(&"muerte", false)

	for textura in SPRITES_MUERTE:
		sprite_frames.add_frame(&"muerte", textura)

	var efecto := AnimatedSprite2D.new()
	efecto.sprite_frames = sprite_frames
	efecto.global_position = global_position
	efecto.z_index = 10
	efecto.scale = Vector2(2, 2)

	current_scene.add_child(efecto)
	efecto.play(&"muerte")

	await efecto.animation_finished
	efecto.queue_free()

# Aplica flash rojo y efecto de sangre al recibir dano
func _reproducir_efecto_dano() -> void:
	var nodo_visual: Node2D = _sprite if _sprite else _visuals
	if not nodo_visual:
		return

	if not is_inside_tree():
		return

	nodo_visual.modulate = Color.RED

	if _esta_vivo:
		_crear_efecto_sangre()

	await get_tree().create_timer(0.1).timeout

	if is_instance_valid(self) and is_inside_tree() and nodo_visual and _esta_vivo:
		nodo_visual.modulate = Color.WHITE

# Crea la animacion de sangre en la posicion del personaje
func _crear_efecto_sangre() -> void:
	var sprite_frames := SpriteFrames.new()
	sprite_frames.remove_animation(&"default")
	sprite_frames.add_animation(&"sangre")
	sprite_frames.set_animation_speed(&"sangre", SANGRE_FPS)
	sprite_frames.set_animation_loop(&"sangre", false)

	for textura in SPRITES_SANGRE:
		sprite_frames.add_frame(&"sangre", textura)

	var efecto := AnimatedSprite2D.new()
	efecto.sprite_frames = sprite_frames
	efecto.global_position = global_position
	efecto.z_index = 10

	get_tree().root.add_child(efecto)
	efecto.play(&"sangre")
	efecto.animation_finished.connect(efecto.queue_free)

# Aplica dano al personaje, el escudo bloquea si el golpe es frontal
func recibir_dano(cantidad: int = 1, posicion_atacante: Vector2 = Vector2.INF) -> void:
	if not _esta_vivo:
		return

	if _arma_actual and is_instance_valid(_arma_actual) and _arma_actual.has_method("bloquear_golpe"):
		if posicion_atacante != Vector2.INF:
			var diferencia_x: float = posicion_atacante.x - global_position.x
			if diferencia_x * _direccion_mirada > 0:
				_arma_actual.bloquear_golpe()
				return

	_vida_actual -= cantidad
	recibio_dano.emit(cantidad)
	_reproducir_efecto_dano()

# Devuelve la vida actual
func obtener_vida() -> int:
	return _vida_actual

# Devuelve si el personaje esta vivo
func esta_vivo() -> bool:
	return _esta_vivo

# Devuelve la direccion de mirada (1 o -1)
func obtener_direccion_mirada() -> int:
	return _direccion_mirada

# Cura al personaje sin exceder la vida maxima
func curar(cantidad: int = 1) -> void:
	if not _esta_vivo:
		return

	_vida_actual = mini(_vida_actual + cantidad, Global.vida_maxima)

# Registra un arma como equipada
func registrar_arma(arma: Node2D) -> void:
	_arma_actual = arma
	arma_equipada.emit(arma)

# Libera la referencia al arma y consume la accion del frame
func liberar_arma() -> void:
	_arma_actual = null
	_accion_consumida_frame = Engine.get_process_frames()
	arma_desequipada.emit()

# Devuelve si tiene un arma equipada
func tiene_arma() -> bool:
	return _arma_actual != null and is_instance_valid(_arma_actual)

# Devuelve si la accion fue consumida en este frame
func accion_consumida_este_frame() -> bool:
	return _accion_consumida_frame == Engine.get_process_frames()

# Devuelve la referencia al arma equipada o null
func obtener_arma() -> Node2D:
	if not is_instance_valid(_arma_actual):
		_arma_actual = null
	return _arma_actual

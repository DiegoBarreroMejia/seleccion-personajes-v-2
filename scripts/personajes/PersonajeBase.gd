extends CharacterBody2D
class_name PersonajeBase

## Clase base para todos los personajes jugables
##
## Maneja movimiento, salto, vida y sistema de dirección.
## Los personajes específicos heredan de esta clase.

# === SEÑALES ===
signal vida_cambiada(nueva_vida: int)
signal murio(id_jugador: int)
signal recibio_dano(cantidad: int)

# === CONSTANTES DE MOVIMIENTO ===
const VELOCIDAD_DEFECTO: float = 300.0
const FUERZA_SALTO_DEFECTO: float = -400.0
const DISTANCIA_MANO: float = 20.0

# === VARIABLES EXPORTADAS ===
@export_group("Movimiento")
@export var speed: float = VELOCIDAD_DEFECTO
@export var jump_velocity: float = FUERZA_SALTO_DEFECTO

@export_group("Configuración Jugador")
@export_range(1, 2) var player_id: int = 1

# === VARIABLES PRIVADAS ===
var _gravity: float = ProjectSettings.get_setting("physics/2d/default_gravity")
var _controls: Dictionary = {}
var _vida_actual: int = 1:
	set(value):
		_vida_actual = maxi(value, 0)
		vida_cambiada.emit(_vida_actual)
		if _vida_actual <= 0:
			_morir()

var _esta_vivo: bool = true
var _direccion_mirada: int = 1
var _estaba_en_suelo: bool = true

# === NODOS CACHEADOS ===
@onready var _sprite: Sprite2D = $Sprite if has_node("Sprite") else null
@onready var _mano: Node2D = _buscar_nodo_mano()
@onready var _visuals: Node2D = $Visuals if has_node("Visuals") else null
@onready var _anim_player: AnimationPlayer = $AnimationPlayer if has_node("AnimationPlayer") else null

var _es_articulado: bool = false

# === MÉTODOS DE CICLO DE VIDA ===

func _ready() -> void:
	_configurar_controles()
	_vida_actual = Global.vida_maxima
	_detectar_tipo_personaje()
	_validar_nodos()
	add_to_group("jugadores")
	
	if _anim_player and _anim_player.has_animation("Reposo"):
		_anim_player.play("Reposo")

func _physics_process(delta: float) -> void:
	if not _esta_vivo:
		return
	
	_aplicar_gravedad(delta)
	_gestionar_movimiento()
	_gestionar_salto()
	_actualizar_animacion()
	move_and_slide()

# === MÉTODOS PRIVADOS - CONFIGURACIÓN ===

func _configurar_controles() -> void:
	_controls = Global.obtener_controles(player_id)
	if _controls.is_empty():
		push_error("PersonajeBase: No se pudieron obtener controles para jugador %d" % player_id)

func _buscar_nodo_mano() -> Node2D:
	if has_node("Mano"):
		return $Mano
	return null

func _detectar_tipo_personaje() -> void:
	_es_articulado = _visuals != null and _sprite == null

func _validar_nodos() -> void:
	if not _sprite and not _visuals:
		push_warning("PersonajeBase: Ni 'Sprite' ni 'Visuals' encontrado en %s" % name)
	if not _mano:
		push_warning("PersonajeBase: Nodo 'Mano' no encontrado en %s" % name)

# === MÉTODOS PRIVADOS - FÍSICA ===

func _aplicar_gravedad(delta: float) -> void:
	if not is_on_floor():
		velocity.y += _gravity * delta

func _gestionar_salto() -> void:
	if _controls.is_empty():
		return
	
	if Input.is_action_just_pressed(_controls["jump"]) and is_on_floor():
		velocity.y = jump_velocity

func _gestionar_movimiento() -> void:
	if _controls.is_empty():
		return
	
	var direction := Input.get_axis(_controls["left"], _controls["right"])
	
	if direction != 0:
		velocity.x = direction * speed
		_actualizar_direccion_mirada(direction)
	else:
		velocity.x = move_toward(velocity.x, 0, speed)

func _actualizar_direccion_mirada(direccion: float) -> void:
	var nueva_direccion: int = 1 if direccion > 0 else -1
	
	if nueva_direccion != _direccion_mirada:
		_direccion_mirada = nueva_direccion
		_voltear_personaje()

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

func _reproducir_animacion(nombre_anim: String) -> void:
	if _anim_player and _anim_player.has_animation(nombre_anim):
		if _anim_player.current_animation != nombre_anim:
			_anim_player.play(nombre_anim)

# === MÉTODOS PRIVADOS - VIDA Y MUERTE ===

func _morir() -> void:
	if not _esta_vivo:
		return
	
	_esta_vivo = false
	print("Jugador %d ha muerto" % player_id)
	
	set_physics_process(false)
	collision_layer = 0
	collision_mask = 0
	
	murio.emit(player_id)
	
	await _reproducir_animacion_muerte()
	
	await get_tree().create_timer(0.5).timeout
	queue_free()

func _reproducir_animacion_muerte() -> void:
	var nodo_visual: Node2D = _sprite if _sprite else _visuals
	if not nodo_visual:
		return
	
	var tween := create_tween()
	tween.tween_property(nodo_visual, "modulate:a", 0.0, 0.3)
	await tween.finished

func _reproducir_efecto_dano() -> void:
	var nodo_visual: Node2D = _sprite if _sprite else _visuals
	if not nodo_visual:
		return
	
	nodo_visual.modulate = Color.RED
	await get_tree().create_timer(0.1).timeout
	
	if is_instance_valid(self) and nodo_visual and _esta_vivo:
		nodo_visual.modulate = Color.WHITE

# === MÉTODOS PÚBLICOS ===

func recibir_dano(cantidad: int = 1) -> void:
	if not _esta_vivo:
		return
	
	_vida_actual -= cantidad
	recibio_dano.emit(cantidad)
	_reproducir_efecto_dano()
	
	print("Jugador %d herido. Vida restante: %d" % [player_id, _vida_actual])

func obtener_vida() -> int:
	return _vida_actual

func esta_vivo() -> bool:
	return _esta_vivo

func obtener_direccion_mirada() -> int:
	return _direccion_mirada

func curar(cantidad: int = 1) -> void:
	if not _esta_vivo:
		return
	
	_vida_actual = mini(_vida_actual + cantidad, Global.vida_maxima)
	print("Jugador %d curado. Vida actual: %d" % [player_id, _vida_actual])

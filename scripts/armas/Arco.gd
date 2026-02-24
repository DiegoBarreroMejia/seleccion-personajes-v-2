extends ArmaBase

const SFX_DISPARO: AudioStream = preload("res://assets/sonidos/Armas/arco/bow.ogg")

const VELOCIDAD_MINIMA_FLECHA: float = 300.0
const VELOCIDAD_MAXIMA_FLECHA: float = 700.0
const TIEMPO_CARGA_COMPLETA: float = 1.5
const ANGULO_DISPARO: float = -0.4

var _sprite_pulling_0: Texture2D = preload("res://assets/sprites/armas/arco_steve/bow_pulling_0.png")
var _sprite_pulling_1: Texture2D = preload("res://assets/sprites/armas/arco_steve/bow_pulling_1.png")
var _sprite_pulling_2: Texture2D = preload("res://assets/sprites/armas/arco_steve/bow_pulling_2.png")

var _cargando: bool = false
var _carga_actual: float = 0.0
var _sprite_nodo: Sprite2D = null
var _sprite_idle: Texture2D = null

# Guarda referencia al sprite y textura idle
func _ready() -> void:
	super._ready()

	if has_node("Sprite2D"):
		_sprite_nodo = $Sprite2D
		_sprite_idle = _sprite_nodo.texture

# Gestiona carga y disparo del arco
func _verificar_input_disparo() -> void:
	var controles := _obtener_controles_dueno()
	if controles.is_empty():
		return

	if Input.is_action_just_pressed(controles["shoot"]) and _puede_disparar:
		_cargando = true
		_carga_actual = 0.0

	if _cargando:
		if Input.is_action_pressed(controles["shoot"]):
			_carga_actual = minf(_carga_actual + get_process_delta_time() / TIEMPO_CARGA_COMPLETA, 1.0)
			_actualizar_sprite_carga()
		else:
			disparar()
			_cargando = false
			_carga_actual = 0.0
			_restaurar_sprite_idle()

# Dispara una flecha con velocidad segun la carga
func disparar() -> void:
	if not bala_scene:
		push_warning("Arco: bala_scene (Flecha) no asignado")
		return

	if not _tiene_municion():
		return

	var flecha := bala_scene.instantiate() as Area2D
	if not flecha:
		return

	var velocidad_flecha := lerpf(VELOCIDAD_MINIMA_FLECHA, VELOCIDAD_MAXIMA_FLECHA, _carga_actual)

	if _punta:
		flecha.global_position = _punta.global_position
	else:
		flecha.global_position = global_position

	if flecha.has_method("establecer_dueno"):
		flecha.establecer_dueno(_id_jugador)

	var direccion := _obtener_direccion_mirada()
	if direccion >= 0:
		flecha.rotation = ANGULO_DISPARO
	else:
		flecha.rotation = PI - ANGULO_DISPARO

	_generar_bala(flecha)

	if flecha.has_method("establecer_velocidad"):
		flecha.establecer_velocidad(velocidad_flecha)

	_consumir_bala()
	_iniciar_cooldown_disparo()
	arma_disparada.emit()

	if _sfx_player:
		_sfx_player.stream = SFX_DISPARO
		_sfx_player.play()

# Cambia sprite segun nivel de carga
func _actualizar_sprite_carga() -> void:
	if not _sprite_nodo:
		return

	if _carga_actual < 0.33:
		_sprite_nodo.texture = _sprite_pulling_0
	elif _carga_actual < 0.66:
		_sprite_nodo.texture = _sprite_pulling_1
	else:
		_sprite_nodo.texture = _sprite_pulling_2

# Restaura sprite al estado idle
func _restaurar_sprite_idle() -> void:
	if _sprite_nodo and _sprite_idle:
		_sprite_nodo.texture = _sprite_idle

# Obtiene la direccion de mirada del dueno
func _obtener_direccion_mirada() -> int:
	var padre := get_parent()
	if padre and padre is Node2D:
		return -1 if padre.scale.x < 0 else 1
	return 1

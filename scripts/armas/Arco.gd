extends ArmaBase

## Arco tipo Minecraft con sistema de carga
##
## Mantener pulsado el botón de disparo carga el arco.
## Al soltar, dispara una flecha cuya velocidad depende de la carga.
## El daño es fijo, solo varía la velocidad.
## El sprite cambia según el nivel de carga (3 fases).

# === CONSTANTES DE CARGA ===
const VELOCIDAD_MINIMA_FLECHA: float = 300.0
const VELOCIDAD_MAXIMA_FLECHA: float = 700.0
const TIEMPO_CARGA_COMPLETA: float = 1.5  # Segundos para carga máxima

## Ángulo de disparo hacia arriba (en radianes). Negativo = hacia arriba.
const ANGULO_DISPARO: float = -0.4  # ~-23 grados hacia arriba

# === SPRITES DE CARGA ===
var _sprite_pulling_0: Texture2D = preload("res://assets/sprites/armas/arco_steve/bow_pulling_0.png")
var _sprite_pulling_1: Texture2D = preload("res://assets/sprites/armas/arco_steve/bow_pulling_1.png")
var _sprite_pulling_2: Texture2D = preload("res://assets/sprites/armas/arco_steve/bow_pulling_2.png")

# === VARIABLES PRIVADAS ===
var _cargando: bool = false
var _carga_actual: float = 0.0  # 0.0 a 1.0
var _sprite_nodo: Sprite2D = null
var _sprite_idle: Texture2D = null

# === CICLO DE VIDA ===

func _ready() -> void:
	super._ready()

	# Guardar referencia al sprite y textura idle
	if has_node("Sprite2D"):
		_sprite_nodo = $Sprite2D
		_sprite_idle = _sprite_nodo.texture

# === SOBRESCRITURA DEL SISTEMA DE DISPARO ===

func _verificar_input_disparo() -> void:
	var controles := _obtener_controles_dueno()
	if controles.is_empty():
		return

	if Input.is_action_just_pressed(controles["shoot"]) and _puede_disparar:
		_cargando = true
		_carga_actual = 0.0

	if _cargando:
		if Input.is_action_pressed(controles["shoot"]):
			# Incrementar carga mientras se mantiene pulsado
			_carga_actual = minf(_carga_actual + get_process_delta_time() / TIEMPO_CARGA_COMPLETA, 1.0)
			_actualizar_sprite_carga()
		else:
			# Soltar botón: disparar
			disparar()
			_cargando = false
			_carga_actual = 0.0
			_restaurar_sprite_idle()

func disparar() -> void:
	if not bala_scene:
		push_warning("Arco: bala_scene (Flecha) no asignado")
		return

	if not _tiene_municion():
		return

	var flecha := bala_scene.instantiate() as Area2D
	if not flecha:
		return

	# Calcular velocidad según carga
	var velocidad_flecha := lerpf(VELOCIDAD_MINIMA_FLECHA, VELOCIDAD_MAXIMA_FLECHA, _carga_actual)

	# Configurar posición (solo posición, no rotación — la ponemos nosotros)
	if _punta:
		flecha.global_position = _punta.global_position
	else:
		flecha.global_position = global_position

	if flecha.has_method("establecer_dueno"):
		flecha.establecer_dueno(_id_jugador)

	# Aplicar ángulo de disparo según la dirección de mirada
	var direccion := _obtener_direccion_mirada()
	if direccion >= 0:
		# Mirando a la derecha: ángulo hacia arriba-derecha
		flecha.rotation = ANGULO_DISPARO
	else:
		# Mirando a la izquierda: PI invertido (hacia arriba-izquierda)
		flecha.rotation = PI - ANGULO_DISPARO

	# IMPORTANTE: Añadir al árbol ANTES de establecer velocidad
	# porque _ready() de Flecha configura el vector, y luego
	# establecer_velocidad() lo reconfigura con la rotación correcta
	_generar_bala(flecha)

	# Establecer velocidad DESPUÉS de añadir al árbol
	if flecha.has_method("establecer_velocidad"):
		flecha.establecer_velocidad(velocidad_flecha)

	_consumir_bala()
	_iniciar_cooldown_disparo()
	arma_disparada.emit()

# === ANIMACIÓN DE CARGA ===

func _actualizar_sprite_carga() -> void:
	if not _sprite_nodo:
		return

	# Determinar qué sprite mostrar según el nivel de carga (3 fases)
	if _carga_actual < 0.33:
		_sprite_nodo.texture = _sprite_pulling_0
	elif _carga_actual < 0.66:
		_sprite_nodo.texture = _sprite_pulling_1
	else:
		_sprite_nodo.texture = _sprite_pulling_2

func _restaurar_sprite_idle() -> void:
	if _sprite_nodo and _sprite_idle:
		_sprite_nodo.texture = _sprite_idle

# === UTILIDADES ===

func _obtener_direccion_mirada() -> int:
	## Obtiene la dirección de mirada del personaje dueño
	## Usa la escala de Mano (el padre del arco cuando está equipado)
	## porque PersonajeBase invierte mano.scale.x según la dirección
	var padre := get_parent()
	if padre and padre is Node2D:
		return -1 if padre.scale.x < 0 else 1
	return 1

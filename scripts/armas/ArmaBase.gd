extends Node2D
class_name ArmaBase

signal arma_disparada()
signal arma_recogida(id_jugador: int)
signal arma_soltada()
signal municion_cambiada(actual: int, maxima: int)

const MAX_CANDIDATOS_RECOGIDA: int = 4
const SFX_RECOGER: AudioStream = preload("res://assets/sonidos/partida/sonido_cuando_un_personaje_coje_algo.ogg")
const SFX_SOLTAR: AudioStream = preload("res://assets/sonidos/partida/sonido_cuando_un_personaje_sualta_algo.ogg")

const GRAVEDAD_ARMA: float = 800.0
const VELOCIDAD_ROTACION: float = 12.0
const DISTANCIA_RAYCAST_MINIMA: float = 15.0

const VELOCIDAD_LANZAMIENTO: float = 600.0
const IMPULSO_VERTICAL_LANZAR: float = -250.0
const IMPULSO_VERTICAL_ARRIBA: float = -550.0
const IMPULSO_HORIZONTAL_ARRIBA: float = 80.0
const VELOCIDAD_INICIAL_SOLTAR: float = 0.0
const TIEMPO_DESAPARICION_SIN_MUNICION: float = 2.0

@export_group("Estadísticas Arma")
@export var bala_scene: PackedScene
@export var velocidad_disparo: float = 0.5
@export var es_automatica: bool = false
@export var dano: int = 1

@export_group("Sonido")
@export var sfx_disparo: AudioStream

@export_group("Munición")
@export var municion_maxima: int = 30

var _puede_disparar: bool = true
var _esta_recogida: bool = false
var _id_jugador: int = 0
var _candidatos_a_recoger: Array[CharacterBody2D] = []
var _temporizador_disparo: Timer
var _desaparicion_activa: bool = false
var _destruida: bool = false
var _id_desaparicion: int = 0

var _municion_actual: int = 0

var _esta_en_vuelo: bool = false
var _fue_lanzada: bool = false
var _velocidad_arma: Vector2 = Vector2.ZERO
var _ultimo_dueno_id: int = 0

@onready var _punta: Marker2D = $Punta if has_node("Punta") else null
@onready var _area_recogida: Area2D = $AreaRecogida if has_node("AreaRecogida") else null
var _sfx_player: AudioStreamPlayer2D = null

# Configura temporizador, area de recogida, municion y sfx
func _ready() -> void:
	_configurar_temporizador_disparo()
	_configurar_area_recogida()
	_inicializar_municion()
	_sfx_player = AudioStreamPlayer2D.new()
	_sfx_player.bus = "SFX"
	_sfx_player.max_distance = 800.0
	add_child(_sfx_player)

# Verifica input de recogida, disparo y soltar cada frame
func _process(_delta: float) -> void:
	if not _esta_recogida and not _esta_en_vuelo:
		_verificar_input_recogida()
	elif _esta_recogida:
		_verificar_input_disparo()
		_verificar_input_soltar()

# Mueve el arma en vuelo con gravedad y rotacion
func _physics_process(delta: float) -> void:
	if not _esta_en_vuelo:
		return

	_velocidad_arma.y += GRAVEDAD_ARMA * delta

	var resultado_suelo := _detectar_suelo()
	if not resultado_suelo.is_empty():
		global_position = resultado_suelo["position"]
		_al_tocar_suelo()
	else:
		position += _velocidad_arma * delta

	if _fue_lanzada:
		rotation += VELOCIDAD_ROTACION * delta

# Crea el temporizador de cooldown de disparo
func _configurar_temporizador_disparo() -> void:
	_temporizador_disparo = Timer.new()
	_temporizador_disparo.one_shot = true
	_temporizador_disparo.timeout.connect(_on_temporizador_disparo_timeout)
	add_child(_temporizador_disparo)

# Conecta senales del area de recogida
func _configurar_area_recogida() -> void:
	if not _area_recogida:
		push_warning("ArmaBase: 'AreaRecogida' no encontrada en %s" % name)
		return

	if not _area_recogida.body_entered.is_connected(_on_area_recogida_body_entered):
		_area_recogida.body_entered.connect(_on_area_recogida_body_entered)

	if not _area_recogida.body_exited.is_connected(_on_area_recogida_body_exited):
		_area_recogida.body_exited.connect(_on_area_recogida_body_exited)

# Verifica si algun candidato pulsa accion para recoger
func _verificar_input_recogida() -> void:
	for personaje in _candidatos_a_recoger:
		if not is_instance_valid(personaje):
			continue

		var controles := Global.obtener_controles(personaje.player_id)
		if controles.is_empty():
			continue

		if Input.is_action_just_pressed(controles["action"]):
			equipar(personaje)
			break

# Equipa el arma al personaje dado
func equipar(nuevo_dueno: CharacterBody2D) -> void:
	if not _puede_ser_equipada_por(nuevo_dueno):
		return

	_esta_en_vuelo = false
	_fue_lanzada = false
	_velocidad_arma = Vector2.ZERO

	_esta_recogida = true
	_id_jugador = nuevo_dueno.player_id
	_candidatos_a_recoger.clear()
	_desaparicion_activa = false

	if nuevo_dueno.has_method("registrar_arma"):
		nuevo_dueno.registrar_arma(self)

	var padre_anterior := get_parent()
	padre_anterior.remove_child(self)

	var mano: Node2D = nuevo_dueno.get_node_or_null("Mano")
	var nuevo_padre := mano if mano else nuevo_dueno

	nuevo_padre.add_child(self)
	position = Vector2.ZERO
	rotation = 0

	modulate.a = 1.0

	if _area_recogida:
		_area_recogida.monitoring = false

	arma_recogida.emit(_id_jugador)
	_emitir_municion_cambiada()

	if _sfx_player:
		_sfx_player.stream = SFX_RECOGER
		_sfx_player.play()

# Verifica si el personaje puede equipar esta arma
func _puede_ser_equipada_por(personaje: CharacterBody2D) -> bool:
	if not is_instance_valid(personaje):
		return false
	if personaje.has_method("esta_vivo") and not personaje.esta_vivo():
		return false
	if personaje.has_method("tiene_arma") and personaje.tiene_arma():
		return false
	if personaje.has_method("accion_consumida_este_frame") and personaje.accion_consumida_este_frame():
		return false
	return true

# Gestiona colision del area: dano en vuelo o agregar candidato
func _on_area_recogida_body_entered(body: Node2D) -> void:
	if _esta_en_vuelo and _fue_lanzada and not _destruida:
		if body is CharacterBody2D and body.is_in_group("jugadores"):
			if "player_id" in body and body.player_id != _ultimo_dueno_id:
				if body.has_method("recibir_dano"):
					_destruida = true
					body.recibir_dano(dano, global_position)
					queue_free()
					return

	if not _esta_en_vuelo and not _esta_recogida:
		if body is CharacterBody2D and body.is_in_group("jugadores"):
			if _candidatos_a_recoger.size() < MAX_CANDIDATOS_RECOGIDA:
				_candidatos_a_recoger.append(body)

# Quita al cuerpo de la lista de candidatos
func _on_area_recogida_body_exited(body: Node2D) -> void:
	if body is CharacterBody2D and body in _candidatos_a_recoger:
		_candidatos_a_recoger.erase(body)

# Verifica input de disparo segun modo automatico o semi
func _verificar_input_disparo() -> void:
	var controles := _obtener_controles_dueno()
	if controles.is_empty():
		return

	var debe_disparar := false
	if es_automatica:
		debe_disparar = Input.is_action_pressed(controles["shoot"])
	else:
		debe_disparar = Input.is_action_just_pressed(controles["shoot"])

	if debe_disparar and _puede_disparar:
		disparar()

# Dispara un proyectil desde la punta del arma
func disparar() -> void:
	if not bala_scene:
		push_warning("ArmaBase: bala_scene no asignado en %s" % name)
		return

	if not _tiene_municion():
		return

	var bala := bala_scene.instantiate() as Area2D
	if not bala:
		return

	_configurar_bala(bala)
	_generar_bala(bala)
	_consumir_bala()

	_iniciar_cooldown_disparo()

	if sfx_disparo and _sfx_player:
		_sfx_player.stream = sfx_disparo
		_sfx_player.play()

	arma_disparada.emit()

# Posiciona y configura la bala antes de dispararla
func _configurar_bala(bala: Area2D) -> void:
	if _punta:
		bala.global_position = _punta.global_position
		bala.global_rotation = _punta.global_rotation
	else:
		bala.global_position = global_position
		bala.global_rotation = global_rotation

	if bala.has_method("establecer_dueno"):
		bala.establecer_dueno(_id_jugador)

# Agrega la bala al arbol de escena
func _generar_bala(bala: Node2D) -> void:
	get_tree().root.add_child(bala)

# Inicia el cooldown de disparo
func _iniciar_cooldown_disparo() -> void:
	_puede_disparar = false
	_temporizador_disparo.start(velocidad_disparo)

# Reactiva el disparo al terminar el cooldown
func _on_temporizador_disparo_timeout() -> void:
	_puede_disparar = true

# Inicializa la municion segun maxima o infinita
func _inicializar_municion() -> void:
	if _tiene_municion_infinita():
		_municion_actual = -1
		return

	_municion_actual = municion_maxima

# Devuelve si la municion es infinita
func _tiene_municion_infinita() -> bool:
	return municion_maxima < 0

# Devuelve si queda municion
func _tiene_municion() -> bool:
	if _tiene_municion_infinita():
		return true
	return _municion_actual > 0

# Resta municion
func _consumir_bala(cantidad: int = 1) -> void:
	if _tiene_municion_infinita():
		return

	_municion_actual = maxi(_municion_actual - cantidad, 0)
	_emitir_municion_cambiada()

# Emite la senal de municion cambiada
func _emitir_municion_cambiada() -> void:
	if _tiene_municion_infinita():
		municion_cambiada.emit(-1, -1)
	else:
		municion_cambiada.emit(_municion_actual, municion_maxima)

# Emite el estado actual de municion para sincronizar HUD
func emitir_estado_municion() -> void:
	_emitir_municion_cambiada()

# Devuelve la municion restante
func obtener_municion_actual() -> int:
	return _municion_actual

# Devuelve si el arma esta sin municion
func esta_sin_municion() -> bool:
	if _tiene_municion_infinita():
		return false
	return _municion_actual <= 0

# Verifica si el dueno pulsa accion para soltar
func _verificar_input_soltar() -> void:
	var controles := _obtener_controles_dueno()
	if controles.is_empty():
		return

	if Input.is_action_just_pressed(controles["action"]):
		soltar()

# Suelta o lanza el arma segun la direccion pulsada
func soltar() -> void:
	var controles := _obtener_controles_dueno()
	var mantiene_abajo := false
	var mantiene_arriba := false
	if not controles.is_empty():
		mantiene_abajo = Input.is_action_pressed(controles["down"])
		mantiene_arriba = Input.is_action_pressed(controles["up"])

	var direccion_lanzamiento := _obtener_direccion_lanzamiento()

	var dueno_actual := _obtener_dueno_personaje()
	if dueno_actual and dueno_actual.has_method("liberar_arma"):
		dueno_actual.liberar_arma()

	_ultimo_dueno_id = _id_jugador
	_esta_recogida = false

	var pos_mundial := global_position
	var raiz := get_tree().root

	get_parent().remove_child(self)
	raiz.add_child(self)

	global_position = pos_mundial
	rotation = 0

	if mantiene_abajo:
		_fue_lanzada = false
		_velocidad_arma = Vector2(0, VELOCIDAD_INICIAL_SOLTAR)
	elif mantiene_arriba:
		_fue_lanzada = true
		_velocidad_arma = Vector2(IMPULSO_HORIZONTAL_ARRIBA * direccion_lanzamiento, IMPULSO_VERTICAL_ARRIBA)
	else:
		_fue_lanzada = true
		_velocidad_arma = Vector2(VELOCIDAD_LANZAMIENTO * direccion_lanzamiento, IMPULSO_VERTICAL_LANZAR)

	_esta_en_vuelo = true
	_desaparicion_activa = false

	if _area_recogida:
		_area_recogida.monitoring = true

	if _sfx_player:
		_sfx_player.stream = SFX_SOLTAR
		_sfx_player.play()

	arma_soltada.emit()

# Inicia temporizador de desaparicion con fade out
func _iniciar_temporizador_desaparicion(tiempo: float = 3.0) -> void:
	_id_desaparicion += 1
	var id_actual := _id_desaparicion
	_desaparicion_activa = true

	await get_tree().create_timer(tiempo).timeout

	if not is_instance_valid(self):
		return
	if _esta_recogida or not _desaparicion_activa or id_actual != _id_desaparicion:
		return

	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.5)
	await tween.finished

	if is_instance_valid(self) and not _esta_recogida:
		queue_free()

# Devuelve la direccion de lanzamiento segun la escala del padre
func _obtener_direccion_lanzamiento() -> int:
	var padre := get_parent()
	if not padre:
		return 1
	return -1 if padre.scale.x < 0 else 1

# Detecta colision con el suelo usando raycast
func _detectar_suelo() -> Dictionary:
	var space_state := get_world_2d().direct_space_state
	if not space_state:
		return {}

	if _velocidad_arma.y < 0:
		return {}

	var delta := get_physics_process_delta_time()
	var distancia_por_velocidad := _velocidad_arma.y * delta + 10.0
	var distancia_raycast := maxf(DISTANCIA_RAYCAST_MINIMA, distancia_por_velocidad)

	var query := PhysicsRayQueryParameters2D.create(
		global_position,
		global_position + Vector2(0, distancia_raycast),
		0b100000
	)
	return space_state.intersect_ray(query)

# Detiene el vuelo y gestiona desaparicion al tocar suelo
func _al_tocar_suelo() -> void:
	_esta_en_vuelo = false
	_velocidad_arma = Vector2.ZERO
	rotation = 0
	_fue_lanzada = false

	_ultimo_dueno_id = 0
	_id_jugador = 0

	if esta_sin_municion():
		_iniciar_temporizador_desaparicion(TIEMPO_DESAPARICION_SIN_MUNICION)
	elif _tiene_municion_infinita():
		_iniciar_temporizador_desaparicion(3.0)
	else:
		pass

# Obtiene el personaje dueno buscando en la jerarquia
func _obtener_dueno_personaje() -> CharacterBody2D:
	var nodo := get_parent()
	while nodo:
		if nodo is CharacterBody2D and nodo.is_in_group("jugadores"):
			return nodo
		nodo = nodo.get_parent()
	return null

# Obtiene los controles del jugador dueno
func _obtener_controles_dueno() -> Dictionary:
	if _id_jugador == 0:
		return {}
	return Global.obtener_controles(_id_jugador)

# Devuelve el id del jugador que tiene el arma
func obtener_id_dueno() -> int:
	return _id_jugador

# Devuelve si el arma esta equipada
func esta_equipada() -> bool:
	return _esta_recogida

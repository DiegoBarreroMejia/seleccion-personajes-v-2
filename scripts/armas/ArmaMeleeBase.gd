extends Node2D
class_name ArmaMeleeBase

signal arma_atacada()
signal arma_recogida(id_jugador: int)
signal arma_soltada()
signal enemigo_golpeado(enemigo: Node2D)

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

@export_group("Estadísticas Arma")
@export var dano: int = 1
@export var velocidad_ataque: float = 0.4
@export var knockback: Vector2 = Vector2(200, -100)

@export_group("Sonido")
@export var sfx_ataque: AudioStream

@export_group("Configuración")
@export var nombre_animacion_ataque: String = "atacar"

var _puede_atacar: bool = true
var _esta_recogida: bool = false
var _id_jugador: int = 0
var _candidatos_a_recoger: Array[CharacterBody2D] = []
var _temporizador_ataque: Timer
var _dueno: CharacterBody2D = null
var _enemigos_golpeados_este_ataque: Array[Node2D] = []
var _desaparicion_activa: bool = false
var _destruida: bool = false
var _id_desaparicion: int = 0
var _atacando: bool = false

var _esta_en_vuelo: bool = false
var _fue_lanzada: bool = false
var _velocidad_arma: Vector2 = Vector2.ZERO
var _ultimo_dueno_id: int = 0

@onready var _area_recogida: Area2D = $AreaRecogida if has_node("AreaRecogida") else null
@onready var _area_dano: Area2D = $AreaDano if has_node("AreaDano") else null
@onready var _anim_player: AnimationPlayer = $AnimationPlayer if has_node("AnimationPlayer") else null
var _sfx_player: AudioStreamPlayer2D = null

# Configura temporizador, areas y sfx
func _ready() -> void:
	_configurar_temporizador_ataque()
	_configurar_area_recogida()
	_configurar_area_dano()
	_sfx_player = AudioStreamPlayer2D.new()
	_sfx_player.bus = "SFX"
	_sfx_player.max_distance = 800.0
	add_child(_sfx_player)

# Verifica input de recogida, ataque y soltar cada frame
func _process(_delta: float) -> void:
	if not _esta_recogida and not _esta_en_vuelo:
		_verificar_input_recogida()
	elif _esta_recogida:
		_verificar_input_ataque()
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

# Crea el temporizador de cooldown de ataque
func _configurar_temporizador_ataque() -> void:
	_temporizador_ataque = Timer.new()
	_temporizador_ataque.one_shot = true
	_temporizador_ataque.timeout.connect(_on_temporizador_ataque_timeout)
	add_child(_temporizador_ataque)

# Conecta senales del area de recogida
func _configurar_area_recogida() -> void:
	if not _area_recogida:
		push_warning("ArmaMeleeBase: 'AreaRecogida' no encontrada en %s" % name)
		return

	if not _area_recogida.body_entered.is_connected(_on_area_recogida_body_entered):
		_area_recogida.body_entered.connect(_on_area_recogida_body_entered)

	if not _area_recogida.body_exited.is_connected(_on_area_recogida_body_exited):
		_area_recogida.body_exited.connect(_on_area_recogida_body_exited)

# Conecta senal del area de dano
func _configurar_area_dano() -> void:
	if not _area_dano:
		push_warning("ArmaMeleeBase: 'AreaDano' no encontrada en %s" % name)
		return

	if not _area_dano.body_entered.is_connected(_on_area_dano_body_entered):
		_area_dano.body_entered.connect(_on_area_dano_body_entered)

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
	_dueno = nuevo_dueno
	_candidatos_a_recoger.clear()
	_desaparicion_activa = false

	if nuevo_dueno.has_method("registrar_arma"):
		nuevo_dueno.registrar_arma(self)

	var padre_anterior := get_parent()
	padre_anterior.remove_child(self)

	var mano: Node2D = nuevo_dueno.get_node_or_null("Mano")
	if not mano:
		mano = nuevo_dueno.get_node_or_null("Visuals/Pivote/Node2D/Mano")

	var nuevo_padre := mano if mano else nuevo_dueno

	nuevo_padre.add_child(self)
	position = Vector2.ZERO
	rotation = 0

	modulate.a = 1.0

	if _area_recogida:
		_area_recogida.monitoring = false

	_al_equipar()
	arma_recogida.emit(_id_jugador)

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
		elif body.has_method("recibir_dano"):
			_destruida = true
			body.recibir_dano(dano)
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

# Verifica si el dueno pulsa disparo para atacar
func _verificar_input_ataque() -> void:
	var controles := _obtener_controles_dueno()
	if controles.is_empty():
		return

	if Input.is_action_just_pressed(controles["shoot"]) and _puede_atacar:
		atacar()

# Ejecuta el ataque con animacion y sonido
func atacar() -> void:
	if not _puede_atacar:
		return

	_atacando = true
	_enemigos_golpeados_este_ataque.clear()

	if _anim_player and _anim_player.has_animation(nombre_animacion_ataque):
		_anim_player.play(nombre_animacion_ataque)

	_iniciar_cooldown_ataque()

	if sfx_ataque and _sfx_player:
		_sfx_player.stream = sfx_ataque
		_sfx_player.play()

	arma_atacada.emit()

# Aplica dano al cuerpo que entra en el area durante el ataque
func _on_area_dano_body_entered(body: Node2D) -> void:
	if not _esta_recogida or not _atacando:
		return

	if body == _dueno:
		return

	if body in _enemigos_golpeados_este_ataque:
		return

	_aplicar_dano(body)
	_enemigos_golpeados_este_ataque.append(body)
	enemigo_golpeado.emit(body)

# Aplica dano y knockback al objetivo
func _aplicar_dano(objetivo: Node2D) -> void:
	var direccion_kb := 1
	if _dueno and _dueno.has_method("obtener_direccion_mirada"):
		direccion_kb = _dueno.obtener_direccion_mirada()

	var kb_final := Vector2(knockback.x * direccion_kb, knockback.y)

	if objetivo.has_method("recibir_hit"):
		objetivo.recibir_hit(dano, kb_final, _dueno)
	elif objetivo.has_method("recibir_dano"):
		objetivo.recibir_dano(dano, global_position)

# Inicia el cooldown de ataque
func _iniciar_cooldown_ataque() -> void:
	_puede_atacar = false
	_temporizador_ataque.start(velocidad_ataque)

# Reactiva el ataque al terminar el cooldown
func _on_temporizador_ataque_timeout() -> void:
	_puede_atacar = true
	_atacando = false

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

	if _dueno and _dueno.has_method("liberar_arma"):
		_dueno.liberar_arma()

	_ultimo_dueno_id = _id_jugador
	_esta_recogida = false
	_dueno = null

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

	_al_soltar()

	if _sfx_player:
		_sfx_player.stream = SFX_SOLTAR
		_sfx_player.play()

	arma_soltada.emit()

# Inicia temporizador de desaparicion con fade out
func _iniciar_temporizador_desaparicion() -> void:
	const TIEMPO_DESAPARICION: float = 5.0

	_id_desaparicion += 1
	var id_actual := _id_desaparicion
	_desaparicion_activa = true

	await get_tree().create_timer(TIEMPO_DESAPARICION).timeout

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
	if padre and padre.scale.x < 0:
		return -1
	return 1

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

# Detiene el vuelo e inicia desaparicion al tocar suelo
func _al_tocar_suelo() -> void:
	_esta_en_vuelo = false
	_velocidad_arma = Vector2.ZERO
	rotation = 0
	_fue_lanzada = false

	_ultimo_dueno_id = 0
	_id_jugador = 0
	_iniciar_temporizador_desaparicion()

# Resetea estado al equipar
func _al_equipar() -> void:
	_atacando = false
	_enemigos_golpeados_este_ataque.clear()
	if _anim_player and _anim_player.has_animation("RESET"):
		_anim_player.play("RESET")

# Resetea estado al soltar
func _al_soltar() -> void:
	_atacando = false
	_enemigos_golpeados_este_ataque.clear()

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

# Devuelve la referencia al dueno
func obtener_dueno() -> CharacterBody2D:
	return _dueno

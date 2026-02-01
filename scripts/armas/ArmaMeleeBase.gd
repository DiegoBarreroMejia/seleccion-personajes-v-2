extends Node2D
class_name ArmaMeleeBase

## Clase base para todas las armas cuerpo a cuerpo del juego
##
## Maneja recogida, ataque y soltar armas melee.
## Las armas específicas pueden sobrescribir atacar() para comportamientos únicos.

# === SEÑALES ===
signal arma_atacada()
signal arma_recogida(id_jugador: int)
signal arma_soltada()
signal enemigo_golpeado(enemigo: Node2D)

# === CONSTANTES ===
const MAX_CANDIDATOS_RECOGIDA: int = 4

# === VARIABLES EXPORTADAS ===
@export_group("Estadísticas Arma")
@export var dano: int = 1
@export var velocidad_ataque: float = 0.4
@export var knockback: Vector2 = Vector2(200, -100)

@export_group("Configuración")
@export var nombre_animacion_ataque: String = "atacar"

# === VARIABLES PRIVADAS ===
var _puede_atacar: bool = true
var _esta_recogida: bool = false
var _id_jugador: int = 0
var _candidatos_a_recoger: Array[CharacterBody2D] = []
var _temporizador_ataque: Timer
var _dueno: CharacterBody2D = null
var _enemigos_golpeados_este_ataque: Array[Node2D] = []
var _desaparicion_activa: bool = false

# === NODOS ===
@onready var _area_recogida: Area2D = $AreaRecogida if has_node("AreaRecogida") else null
@onready var _area_dano: Area2D = $AreaDano if has_node("AreaDano") else null
@onready var _anim_player: AnimationPlayer = $AnimationPlayer if has_node("AnimationPlayer") else null
@onready var _sprite: Sprite2D = $Sprite2D if has_node("Sprite2D") else null

# === MÉTODOS DE CICLO DE VIDA ===

func _ready() -> void:
	_configurar_temporizador_ataque()
	_configurar_area_recogida()
	_configurar_area_dano()

func _process(_delta: float) -> void:
	if not _esta_recogida:
		_verificar_input_recogida()
	else:
		_verificar_input_ataque()
		_verificar_input_soltar()

# === CONFIGURACIÓN INICIAL ===

func _configurar_temporizador_ataque() -> void:
	_temporizador_ataque = Timer.new()
	_temporizador_ataque.one_shot = true
	_temporizador_ataque.timeout.connect(_on_temporizador_ataque_timeout)
	add_child(_temporizador_ataque)

func _configurar_area_recogida() -> void:
	if not _area_recogida:
		push_warning("ArmaMeleeBase: 'AreaRecogida' no encontrada en %s" % name)
		return
	
	if not _area_recogida.body_entered.is_connected(_on_area_recogida_body_entered):
		_area_recogida.body_entered.connect(_on_area_recogida_body_entered)

	if not _area_recogida.body_exited.is_connected(_on_area_recogida_body_exited):
		_area_recogida.body_exited.connect(_on_area_recogida_body_exited)

func _configurar_area_dano() -> void:
	if not _area_dano:
		push_warning("ArmaMeleeBase: 'AreaDano' no encontrada en %s" % name)
		return
	
	if not _area_dano.body_entered.is_connected(_on_area_dano_body_entered):
		_area_dano.body_entered.connect(_on_area_dano_body_entered)

# === SISTEMA DE RECOGIDA ===

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

func equipar(nuevo_dueno: CharacterBody2D) -> void:
	if not _puede_ser_equipada_por(nuevo_dueno):
		return
	
	_esta_recogida = true
	_id_jugador = nuevo_dueno.player_id
	_dueno = nuevo_dueno
	_candidatos_a_recoger.clear()
	_desaparicion_activa = false
	
	# Reparentar
	var padre_anterior := get_parent()
	padre_anterior.remove_child(self)
	
	var mano: Node2D = nuevo_dueno.get_node_or_null("Mano")
	if not mano:
		mano = nuevo_dueno.get_node_or_null("Visuals/Pivote/Node2D/Mano")
	
	var nuevo_padre := mano if mano else nuevo_dueno
	
	nuevo_padre.add_child(self)
	position = Vector2.ZERO
	rotation = 0
	
	# Restaurar visibilidad
	modulate.a = 1.0
	
	# Desactivar área de recogida mientras está equipada
	if _area_recogida:
		_area_recogida.monitoring = false
	
	_al_equipar()
	arma_recogida.emit(_id_jugador)
	print("Arma melee equipada por Jugador %d" % _id_jugador)

func _puede_ser_equipada_por(personaje: CharacterBody2D) -> bool:
	if not is_instance_valid(personaje):
		return false
	if personaje.has_method("esta_vivo") and not personaje.esta_vivo():
		return false
	return true

func _on_area_recogida_body_entered(body: Node2D) -> void:
	if body is CharacterBody2D and body.is_in_group("jugadores"):
		if _candidatos_a_recoger.size() < MAX_CANDIDATOS_RECOGIDA:
			_candidatos_a_recoger.append(body)

func _on_area_recogida_body_exited(body: Node2D) -> void:
	if body in _candidatos_a_recoger:
		_candidatos_a_recoger.erase(body)

# === SISTEMA DE ATAQUE ===

func _verificar_input_ataque() -> void:
	var controles := _obtener_controles_dueno()
	if controles.is_empty():
		return
	
	if Input.is_action_just_pressed(controles["shoot"]) and _puede_atacar:
		atacar()

## Realiza un ataque. Sobrescribir en armas específicas para comportamientos únicos
func atacar() -> void:
	if not _puede_atacar:
		return
	
	_enemigos_golpeados_este_ataque.clear()
	
	if _anim_player and _anim_player.has_animation(nombre_animacion_ataque):
		_anim_player.play(nombre_animacion_ataque)
	
	_iniciar_cooldown_ataque()
	arma_atacada.emit()

func _on_area_dano_body_entered(body: Node2D) -> void:
	if not _esta_recogida:
		return
	
	if body == _dueno:
		return
	
	if body in _enemigos_golpeados_este_ataque:
		return
	
	_aplicar_dano(body)
	_enemigos_golpeados_este_ataque.append(body)
	enemigo_golpeado.emit(body)

func _aplicar_dano(objetivo: Node2D) -> void:
	var direccion_kb := 1
	if _dueno and _dueno.has_method("obtener_direccion_mirada"):
		direccion_kb = _dueno.obtener_direccion_mirada()
	
	var kb_final := Vector2(knockback.x * direccion_kb, knockback.y)
	
	if objetivo.has_method("recibir_hit"):
		objetivo.recibir_hit(dano, kb_final, _dueno)
	elif objetivo.has_method("recibir_dano"):
		objetivo.recibir_dano(dano)
	
	print("Arma melee golpeó a %s por %d de daño" % [objetivo.name, dano])

func _iniciar_cooldown_ataque() -> void:
	_puede_atacar = false
	_temporizador_ataque.start(velocidad_ataque)

func _on_temporizador_ataque_timeout() -> void:
	_puede_atacar = true

# === SISTEMA DE SOLTAR ===

func _verificar_input_soltar() -> void:
	var controles := _obtener_controles_dueno()
	if controles.is_empty():
		return
	
	if Input.is_action_just_pressed(controles["action"]):
		soltar()

func soltar() -> void:
	_esta_recogida = false
	_dueno = null
	
	var direccion_lanzamiento := _obtener_direccion_lanzamiento()
	var pos_mundial := global_position
	var raiz := get_tree().root
	
	get_parent().remove_child(self)
	raiz.add_child(self)
	
	global_position = pos_mundial
	rotation = 0
	
	position.x += 40 * direccion_lanzamiento
	
	if _area_recogida:
		_area_recogida.monitoring = true
	
	_al_soltar()
	arma_soltada.emit()
	
	await get_tree().create_timer(0.5).timeout
	if is_instance_valid(self):
		_id_jugador = 0
		_iniciar_temporizador_desaparicion()

func _iniciar_temporizador_desaparicion() -> void:
	const TIEMPO_DESAPARICION: float = 5.0
	
	_desaparicion_activa = true
	
	await get_tree().create_timer(TIEMPO_DESAPARICION).timeout
	
	if not is_instance_valid(self):
		return
	if _esta_recogida or not _desaparicion_activa:
		return
	
	print("Arma melee desapareciendo después de %.1f segundos" % TIEMPO_DESAPARICION)
	
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.5)
	await tween.finished
	
	if is_instance_valid(self) and not _esta_recogida:
		queue_free()

func _obtener_direccion_lanzamiento() -> int:
	var padre := get_parent()
	if padre and padre.scale.x < 0:
		return -1
	return 1

# === MÉTODOS VIRTUALES ===

func _al_equipar() -> void:
	_enemigos_golpeados_este_ataque.clear()
	if _anim_player and _anim_player.has_animation("RESET"):
		_anim_player.play("RESET")

func _al_soltar() -> void:
	_enemigos_golpeados_este_ataque.clear()

# === UTILIDADES ===

func _obtener_controles_dueno() -> Dictionary:
	if _id_jugador == 0:
		return {}
	return Global.obtener_controles(_id_jugador)

func obtener_id_dueno() -> int:
	return _id_jugador

func esta_equipada() -> bool:
	return _esta_recogida

func obtener_dueno() -> CharacterBody2D:
	return _dueno

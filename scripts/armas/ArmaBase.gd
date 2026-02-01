extends Node2D
class_name ArmaBase

## Clase base para todas las armas de fuego del juego
##
## Maneja recogida, disparo y soltar armas.
## Las armas específicas pueden sobrescribir disparar() para comportamientos únicos.

# === SEÑALES ===
signal arma_disparada()
signal arma_recogida(id_jugador: int)
signal arma_soltada()

# === CONSTANTES ===
const MAX_CANDIDATOS_RECOGIDA: int = 4

# === VARIABLES EXPORTADAS ===
@export_group("Estadísticas Arma")
@export var bala_scene: PackedScene
@export var velocidad_disparo: float = 0.5
@export var es_automatica: bool = false
@export var dano: int = 1

# === VARIABLES PRIVADAS ===
var _puede_disparar: bool = true
var _esta_recogida: bool = false
var _id_jugador: int = 0
var _candidatos_a_recoger: Array[CharacterBody2D] = []
var _temporizador_disparo: Timer
var _desaparicion_activa: bool = false

# === NODOS ===
@onready var _punta: Marker2D = $Punta if has_node("Punta") else null
@onready var _area_recogida: Area2D = $AreaRecogida if has_node("AreaRecogida") else null

# === MÉTODOS DE CICLO DE VIDA ===

func _ready() -> void:
	_configurar_temporizador_disparo()
	_configurar_area_recogida()

func _process(_delta: float) -> void:
	if not _esta_recogida:
		_verificar_input_recogida()
	else:
		_verificar_input_disparo()
		_verificar_input_soltar()

# === CONFIGURACIÓN INICIAL ===

func _configurar_temporizador_disparo() -> void:
	_temporizador_disparo = Timer.new()
	_temporizador_disparo.one_shot = true
	_temporizador_disparo.timeout.connect(_on_temporizador_disparo_timeout)
	add_child(_temporizador_disparo)

func _configurar_area_recogida() -> void:
	if not _area_recogida:
		push_warning("ArmaBase: 'AreaRecogida' no encontrada en %s" % name)
		return
	
	if not _area_recogida.body_entered.is_connected(_on_area_recogida_body_entered):
		_area_recogida.body_entered.connect(_on_area_recogida_body_entered)

	if not _area_recogida.body_exited.is_connected(_on_area_recogida_body_exited):
		_area_recogida.body_exited.connect(_on_area_recogida_body_exited)

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
	_candidatos_a_recoger.clear()
	_desaparicion_activa = false
	
	# Reparentar
	var padre_anterior := get_parent()
	padre_anterior.remove_child(self)
	
	var mano: Node2D = nuevo_dueno.get_node_or_null("Mano")
	var nuevo_padre := mano if mano else nuevo_dueno
	
	nuevo_padre.add_child(self)
	position = Vector2.ZERO
	rotation = 0
	
	# Restaurar visibilidad por si estaba desvaneciéndose
	modulate.a = 1.0
	
	arma_recogida.emit(_id_jugador)
	print("Arma equipada por Jugador %d" % _id_jugador)

func _puede_ser_equipada_por(personaje: CharacterBody2D) -> bool:
	if not is_instance_valid(personaje):
		return false
	if personaje.has_method("esta_vivo") and not personaje.esta_vivo():
		return false
	return true

func _on_area_recogida_body_entered(body: Node2D) -> void:
	if body is CharacterBody2D and _candidatos_a_recoger.size() < MAX_CANDIDATOS_RECOGIDA:
		_candidatos_a_recoger.append(body)

func _on_area_recogida_body_exited(body: Node2D) -> void:
	if body in _candidatos_a_recoger:
		_candidatos_a_recoger.erase(body)

# === SISTEMA DE DISPARO ===

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

## Dispara el arma. Sobrescribir en armas específicas para comportamientos únicos
func disparar() -> void:
	if not bala_scene:
		push_warning("ArmaBase: bala_scene no asignado en %s" % name)
		return
	
	var bala := bala_scene.instantiate() as Area2D
	if not bala:
		return
	
	_configurar_bala(bala)
	_generar_bala(bala)
	
	_iniciar_cooldown_disparo()
	arma_disparada.emit()

func _configurar_bala(bala: Area2D) -> void:
	if _punta:
		bala.global_position = _punta.global_position
		bala.global_rotation = _punta.global_rotation
	else:
		bala.global_position = global_position
		bala.global_rotation = global_rotation
	
	if bala.has_method("establecer_dueno"):
		bala.establecer_dueno(_id_jugador)

func _generar_bala(bala: Node2D) -> void:
	get_tree().root.add_child(bala)

func _iniciar_cooldown_disparo() -> void:
	_puede_disparar = false
	_temporizador_disparo.start(velocidad_disparo)

func _on_temporizador_disparo_timeout() -> void:
	_puede_disparar = true

# === SISTEMA DE SOLTAR ===

func _verificar_input_soltar() -> void:
	var controles := _obtener_controles_dueno()
	if controles.is_empty():
		return
	
	if Input.is_action_just_pressed(controles["action"]):
		soltar()

func soltar() -> void:
	_esta_recogida = false
	
	var direccion_lanzamiento := _obtener_direccion_lanzamiento()
	var pos_mundial := global_position
	var raiz := get_tree().root
	
	get_parent().remove_child(self)
	raiz.add_child(self)
	
	global_position = pos_mundial
	rotation = 0
	
	# Lanzar hacia adelante
	position.x += 40 * direccion_lanzamiento
	
	arma_soltada.emit()
	
	# Cooldown antes de poder recogerla de nuevo
	await get_tree().create_timer(0.5).timeout
	if is_instance_valid(self):
		_id_jugador = 0
		_iniciar_temporizador_desaparicion()

func _iniciar_temporizador_desaparicion() -> void:
	const TIEMPO_DESAPARICION: float = 3.0
	
	_desaparicion_activa = true
	
	await get_tree().create_timer(TIEMPO_DESAPARICION).timeout
	
	# Verificaciones de seguridad
	if not is_instance_valid(self):
		return
	if _esta_recogida or not _desaparicion_activa:
		return
	
	print("Arma desapareciendo después de %.1f segundos en el suelo" % TIEMPO_DESAPARICION)
	
	# Animación de desvanecimiento
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.5)
	await tween.finished
	
	if is_instance_valid(self) and not _esta_recogida:
		queue_free()

func _obtener_direccion_lanzamiento() -> int:
	var padre := get_parent()
	return -1 if padre.scale.x < 0 else 1

# === UTILIDADES ===

func _obtener_controles_dueno() -> Dictionary:
	if _id_jugador == 0:
		return {}
	return Global.obtener_controles(_id_jugador)

## Obtiene el ID del jugador que tiene el arma
func obtener_id_dueno() -> int:
	return _id_jugador

## Verifica si el arma está equipada
func esta_equipada() -> bool:
	return _esta_recogida

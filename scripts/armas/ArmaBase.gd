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

# === CONSTANTES DE FÍSICA DE ARMAS ===
const GRAVEDAD_ARMA: float = 800.0
const VELOCIDAD_ROTACION: float = 12.0
const DISTANCIA_RAYCAST_MINIMA: float = 15.0

# === CONSTANTES DE LANZAMIENTO HORIZONTAL (proyectil con arco) ===
const VELOCIDAD_LANZAMIENTO: float = 600.0
const IMPULSO_VERTICAL_LANZAR: float = -250.0  # Negativo = hacia arriba (arco parabólico)

# === CONSTANTES DE LANZAMIENTO HACIA ARRIBA ===
const IMPULSO_VERTICAL_ARRIBA: float = -550.0  # Fuerza hacia arriba
const IMPULSO_HORIZONTAL_ARRIBA: float = 80.0  # Pequeño ángulo horizontal

# === CONSTANTES DE SOLTAR (caída natural) ===
const VELOCIDAD_INICIAL_SOLTAR: float = 0.0  # Sin impulso, solo gravedad

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

# === VARIABLES DE VUELO/LANZAMIENTO ===
var _esta_en_vuelo: bool = false
var _fue_lanzada: bool = false  # true = lanzada (daña y desaparece), false = soltada (recogible)
var _velocidad_arma: Vector2 = Vector2.ZERO
var _ultimo_dueno_id: int = 0  # Para no dañar al que la lanzó

# === NODOS ===
@onready var _punta: Marker2D = $Punta if has_node("Punta") else null
@onready var _area_recogida: Area2D = $AreaRecogida if has_node("AreaRecogida") else null

# === MÉTODOS DE CICLO DE VIDA ===

func _ready() -> void:
	_configurar_temporizador_disparo()
	_configurar_area_recogida()

func _process(_delta: float) -> void:
	if not _esta_recogida and not _esta_en_vuelo:
		_verificar_input_recogida()
	elif _esta_recogida:
		_verificar_input_disparo()
		_verificar_input_soltar()

func _physics_process(delta: float) -> void:
	if not _esta_en_vuelo:
		return

	# Aplicar gravedad
	_velocidad_arma.y += GRAVEDAD_ARMA * delta

	# Detectar colisión con suelo antes de mover
	var resultado_suelo := _detectar_suelo()
	if not resultado_suelo.is_empty():
		# Posicionar exactamente sobre el suelo
		global_position = resultado_suelo["position"]
		_al_tocar_suelo()
	else:
		# Mover arma normalmente
		position += _velocidad_arma * delta

	# Rotar visualmente si fue lanzada
	if _fue_lanzada:
		rotation += VELOCIDAD_ROTACION * delta

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

	# Cancelar vuelo si estaba en el aire
	_esta_en_vuelo = false
	_fue_lanzada = false
	_velocidad_arma = Vector2.ZERO

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
	# Si está en vuelo y fue lanzada, puede hacer daño
	if _esta_en_vuelo and _fue_lanzada:
		if body is CharacterBody2D and body.is_in_group("jugadores"):
			# No dañar al que la lanzó
			if "player_id" in body and body.player_id != _ultimo_dueno_id:
				if body.has_method("recibir_dano"):
					body.recibir_dano(dano)
					print("Arma lanzada golpeó a Jugador %d" % body.player_id)
					queue_free()
					return

	# Comportamiento normal: añadir a candidatos para recoger
	if not _esta_en_vuelo and not _esta_recogida:
		if body is CharacterBody2D and body.is_in_group("jugadores"):
			if _candidatos_a_recoger.size() < MAX_CANDIDATOS_RECOGIDA:
				_candidatos_a_recoger.append(body)

func _on_area_recogida_body_exited(body: Node2D) -> void:
	if body is CharacterBody2D and body in _candidatos_a_recoger:
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
	# Detectar direcciones pulsadas
	var controles := _obtener_controles_dueno()
	var mantiene_abajo := false
	var mantiene_arriba := false
	if not controles.is_empty():
		mantiene_abajo = Input.is_action_pressed(controles["down"])
		mantiene_arriba = Input.is_action_pressed(controles["up"])

	var direccion_lanzamiento := _obtener_direccion_lanzamiento()

	# Guardar referencia al dueño antes de soltar
	_ultimo_dueno_id = _id_jugador
	_esta_recogida = false

	var pos_mundial := global_position
	var raiz := get_tree().root

	get_parent().remove_child(self)
	raiz.add_child(self)

	global_position = pos_mundial
	rotation = 0

	# Configurar modo según input del jugador (prioridad: abajo > arriba > horizontal)
	if mantiene_abajo:
		# MODO SOLTAR: caída natural por gravedad, sin impulso inicial
		_fue_lanzada = false
		_velocidad_arma = Vector2(0, VELOCIDAD_INICIAL_SOLTAR)
		print("Arma soltada (caída natural)")
	elif mantiene_arriba:
		# MODO LANZAR ARRIBA: proyectil hacia arriba con ligero ángulo
		_fue_lanzada = true
		_velocidad_arma = Vector2(IMPULSO_HORIZONTAL_ARRIBA * direccion_lanzamiento, IMPULSO_VERTICAL_ARRIBA)
		print("Arma lanzada hacia arriba")
	else:
		# MODO LANZAR HORIZONTAL: proyectil con arco parabólico
		_fue_lanzada = true
		_velocidad_arma = Vector2(VELOCIDAD_LANZAMIENTO * direccion_lanzamiento, IMPULSO_VERTICAL_LANZAR)
		print("Arma lanzada (proyectil)")

	_esta_en_vuelo = true
	_desaparicion_activa = false
	arma_soltada.emit()

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
	if not padre:
		return 1
	return -1 if padre.scale.x < 0 else 1

# === SISTEMA DE VUELO ===

func _detectar_suelo() -> Dictionary:
	## Detecta si el arma tocó el suelo usando raycast
	## Retorna el punto de colisión o diccionario vacío si no hay colisión
	var space_state := get_world_2d().direct_space_state
	if not space_state:
		return {}

	# Solo detectar suelo cuando el arma está cayendo o estática
	# Si está subiendo (velocidad Y negativa), no buscar colisión con suelo
	if _velocidad_arma.y < 0:
		return {}

	# Calcular distancia del raycast proporcional a la velocidad de caída
	# Esto evita que el arma "atraviese" el suelo a alta velocidad
	var delta := get_physics_process_delta_time()
	var distancia_por_velocidad := _velocidad_arma.y * delta + 10.0
	var distancia_raycast := maxf(DISTANCIA_RAYCAST_MINIMA, distancia_por_velocidad)

	var query := PhysicsRayQueryParameters2D.create(
		global_position,
		global_position + Vector2(0, distancia_raycast),
		0b100000  # Layer 6: Escenario
	)
	return space_state.intersect_ray(query)

func _al_tocar_suelo() -> void:
	## Comportamiento al tocar el suelo
	## Tanto si fue lanzada como soltada, el arma queda en el suelo recogible
	## Solo desaparece si impacta directamente con un personaje (gestionado en _on_area_recogida_body_entered)
	_esta_en_vuelo = false
	_velocidad_arma = Vector2.ZERO
	rotation = 0
	_fue_lanzada = false  # Ya no está en modo "proyectil", ahora es recogible

	# El arma queda en el suelo, disponible para recoger
	print("Arma en el suelo, puede recogerse")
	_ultimo_dueno_id = 0
	_id_jugador = 0
	_iniciar_temporizador_desaparicion()

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

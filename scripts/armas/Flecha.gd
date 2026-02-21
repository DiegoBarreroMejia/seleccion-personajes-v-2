extends Area2D
class_name Flecha

## Proyectil de flecha con gravedad (estilo Minecraft)
##
## Se mueve con arco parabólico y rota visualmente para apuntar
## en la dirección de movimiento. Se destruye al impactar.

# === CONSTANTES ===
const GRAVEDAD: float = 400.0
const TIEMPO_VIDA_DEFECTO: float = 8.0
const SFX_IMPACTO: AudioStream = preload("res://assets/sonidos/Armas/arco/bowhit1.ogg")

# === VARIABLES EXPORTADAS ===
@export var velocidad: float = 500.0
@export var dano: int = 2
@export var tiempo_vida: float = TIEMPO_VIDA_DEFECTO

# === VARIABLES PRIVADAS ===
var _velocidad_vector: Vector2 = Vector2.ZERO
var _temporizador_vida: Timer
var _id_jugador_dueno: int = 0
var _destruida: bool = false
var _velocidad_configurada: bool = false  # True si establecer_velocidad fue llamado

# === MÉTODOS PÚBLICOS ===

func establecer_dueno(id_jugador: int) -> void:
	_id_jugador_dueno = id_jugador

func establecer_velocidad(nueva_velocidad: float) -> void:
	velocidad = nueva_velocidad
	# Configurar el vector de velocidad con la rotación actual
	_velocidad_vector = Vector2.RIGHT.rotated(rotation) * velocidad
	_velocidad_configurada = true

	# Flip visual si va hacia la izquierda
	if _velocidad_vector.x < 0 and has_node("Sprite2D"):
		$Sprite2D.flip_v = true

# === MÉTODOS DE CICLO DE VIDA ===

func _ready() -> void:
	# Solo configurar velocidad si no fue establecida externamente
	if not _velocidad_configurada:
		_velocidad_vector = Vector2.RIGHT.rotated(rotation) * velocidad

	_configurar_temporizador_vida()
	_conectar_senales()

func _physics_process(delta: float) -> void:
	if _destruida:
		return

	# Aplicar gravedad
	_velocidad_vector.y += GRAVEDAD * delta

	# Mover
	position += _velocidad_vector * delta

	# Rotar sprite para apuntar en dirección del movimiento
	rotation = _velocidad_vector.angle()

# === CONFIGURACIÓN INICIAL ===

func _configurar_temporizador_vida() -> void:
	_temporizador_vida = Timer.new()
	_temporizador_vida.one_shot = true
	_temporizador_vida.wait_time = tiempo_vida
	add_child(_temporizador_vida)
	_temporizador_vida.timeout.connect(_on_tiempo_vida_agotado)
	_temporizador_vida.start()

func _conectar_senales() -> void:
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)

	if has_node("VisibleOnScreenNotifier2D"):
		var notificador := $VisibleOnScreenNotifier2D as VisibleOnScreenNotifier2D
		if not notificador.screen_exited.is_connected(_on_screen_exited):
			notificador.screen_exited.connect(_on_screen_exited)

# === COLISIONES ===

func _on_body_entered(body: Node2D) -> void:
	if _destruida:
		return

	# Ignorar al jugador que disparó
	if "player_id" in body and body.player_id == _id_jugador_dueno:
		return

	# Colisión con paredes/suelo
	if body is TileMap or body is StaticBody2D:
		_destruir()
		return

	# Colisión con personaje
	if body.has_method("recibir_dano"):
		body.recibir_dano(dano)
		_destruir()

func _on_screen_exited() -> void:
	_destruir()

func _on_tiempo_vida_agotado() -> void:
	_destruir()

# === DESTRUCCIÓN ===

func _destruir() -> void:
	if _destruida:
		return

	_destruida = true
	set_physics_process(false)
	_reproducir_sonido_impacto()
	queue_free()

# === SONIDO DE IMPACTO ===

func _reproducir_sonido_impacto() -> void:
	## Crea un AudioStreamPlayer2D temporal en el root que sobrevive al queue_free()
	var sfx := AudioStreamPlayer2D.new()
	sfx.stream = SFX_IMPACTO
	sfx.bus = "SFX"
	sfx.max_distance = 800.0
	sfx.global_position = global_position
	get_tree().root.add_child(sfx)
	sfx.play()
	# Auto-limpieza al terminar de reproducir
	sfx.finished.connect(sfx.queue_free)

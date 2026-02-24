extends Area2D
class_name Flecha

const GRAVEDAD: float = 400.0
const TIEMPO_VIDA_DEFECTO: float = 8.0
const SFX_IMPACTO: AudioStream = preload("res://assets/sonidos/Armas/arco/bowhit1.ogg")

@export var velocidad: float = 500.0
@export var dano: int = 2
@export var tiempo_vida: float = TIEMPO_VIDA_DEFECTO

var _velocidad_vector: Vector2 = Vector2.ZERO
var _temporizador_vida: Timer
var _id_jugador_dueno: int = 0
var _destruida: bool = false
var _velocidad_configurada: bool = false

# Establece el id del jugador que disparo
func establecer_dueno(id_jugador: int) -> void:
	_id_jugador_dueno = id_jugador

# Configura velocidad desde el arco y voltea sprite si va a la izquierda
func establecer_velocidad(nueva_velocidad: float) -> void:
	velocidad = nueva_velocidad
	_velocidad_vector = Vector2.RIGHT.rotated(rotation) * velocidad
	_velocidad_configurada = true

	if _velocidad_vector.x < 0 and has_node("Sprite2D"):
		$Sprite2D.flip_v = true

# Configura velocidad por defecto, temporizador y senales
func _ready() -> void:
	if not _velocidad_configurada:
		_velocidad_vector = Vector2.RIGHT.rotated(rotation) * velocidad

	_configurar_temporizador_vida()
	_conectar_senales()

# Aplica gravedad, mueve y rota la flecha
func _physics_process(delta: float) -> void:
	if _destruida:
		return

	_velocidad_vector.y += GRAVEDAD * delta
	position += _velocidad_vector * delta
	rotation = _velocidad_vector.angle()

# Crea el temporizador de vida
func _configurar_temporizador_vida() -> void:
	_temporizador_vida = Timer.new()
	_temporizador_vida.one_shot = true
	_temporizador_vida.wait_time = tiempo_vida
	add_child(_temporizador_vida)
	_temporizador_vida.timeout.connect(_on_tiempo_vida_agotado)
	_temporizador_vida.start()

# Conecta senales de colision y pantalla
func _conectar_senales() -> void:
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)

	if has_node("VisibleOnScreenNotifier2D"):
		var notificador := $VisibleOnScreenNotifier2D as VisibleOnScreenNotifier2D
		if not notificador.screen_exited.is_connected(_on_screen_exited):
			notificador.screen_exited.connect(_on_screen_exited)

# Aplica dano o se destruye al colisionar
func _on_body_entered(body: Node2D) -> void:
	if _destruida:
		return

	if "player_id" in body and body.player_id == _id_jugador_dueno:
		return

	if body.has_method("recibir_dano"):
		body.recibir_dano(dano, global_position)
		_destruir()
		return

	if body is TileMap or body is StaticBody2D:
		_destruir()
		return

# Se destruye al salir de pantalla
func _on_screen_exited() -> void:
	_destruir()

# Se destruye al agotar tiempo de vida
func _on_tiempo_vida_agotado() -> void:
	_destruir()

# Destruye la flecha y reproduce sonido de impacto
func _destruir() -> void:
	if _destruida:
		return

	_destruida = true
	set_physics_process(false)
	_reproducir_sonido_impacto()
	queue_free()

# Crea un reproductor de sonido temporal en el root
func _reproducir_sonido_impacto() -> void:
	var sfx := AudioStreamPlayer2D.new()
	sfx.stream = SFX_IMPACTO
	sfx.bus = "SFX"
	sfx.max_distance = 800.0
	sfx.global_position = global_position
	get_tree().root.add_child(sfx)
	sfx.play()
	sfx.finished.connect(sfx.queue_free)

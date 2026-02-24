extends ArmaMeleeBase

const SFX_BLOQUEO: AudioStream = preload("res://assets/sonidos/Armas/sonido_escudo_kratos.ogg")
const RESISTENCIA_MAXIMA: int = 3
const EMPUJE := Vector2(2000, -300)

var _resistencia: int = RESISTENCIA_MAXIMA
@onready var _col_escudo: CollisionShape2D = $CuerpoEscudo/CollisionShape2D

# Configura valores del escudo
func _ready() -> void:
	dano = 0
	velocidad_ataque = 0.6
	knockback = EMPUJE
	nombre_animacion_ataque = "atacar"

	super._ready()

	_col_escudo.set_deferred("disabled", true)

# Activa barrera fisica y excepciones de colision al equipar
func _al_equipar() -> void:
	super._al_equipar()
	_col_escudo.set_deferred("disabled", false)
	_agregar_excepciones_jugadores()

# Desactiva barrera fisica y limpia excepciones al soltar
func _al_soltar() -> void:
	_quitar_excepciones_jugadores()
	_col_escudo.set_deferred("disabled", true)
	super._al_soltar()

# Agrega excepciones de colision con todos los jugadores
func _agregar_excepciones_jugadores() -> void:
	for jugador in get_tree().get_nodes_in_group("jugadores"):
		if jugador is CharacterBody2D:
			jugador.add_collision_exception_with($CuerpoEscudo)

# Quita excepciones de colision con todos los jugadores
func _quitar_excepciones_jugadores() -> void:
	for jugador in get_tree().get_nodes_in_group("jugadores"):
		if is_instance_valid(jugador) and jugador is CharacterBody2D:
			jugador.remove_collision_exception_with($CuerpoEscudo)

# Ejecuta el ataque (shield bash)
func atacar() -> void:
	super.atacar()

# Solo empuja al objetivo sin infligir dano
func _aplicar_dano(objetivo: Node2D) -> void:
	if objetivo is CharacterBody2D:
		var dir := 1
		if _dueno and _dueno.has_method("obtener_direccion_mirada"):
			dir = _dueno.obtener_direccion_mirada()
		objetivo.velocity = Vector2(EMPUJE.x * dir, EMPUJE.y)

# Resta resistencia, reproduce sonido y destruye si llega a 0
func bloquear_golpe() -> void:
	_resistencia -= 1

	var sfx := AudioStreamPlayer2D.new()
	sfx.stream = SFX_BLOQUEO
	sfx.bus = "SFX"
	sfx.max_distance = 800.0
	sfx.global_position = global_position
	get_tree().root.add_child(sfx)
	sfx.play()
	sfx.finished.connect(sfx.queue_free)

	if _resistencia <= 0:
		call_deferred("_destruir_escudo")

# Destruye el escudo limpiamente
func _destruir_escudo() -> void:
	_quitar_excepciones_jugadores()
	if _dueno and is_instance_valid(_dueno):
		if _dueno.has_method("liberar_arma"):
			_dueno.liberar_arma()

	_col_escudo.set_deferred("disabled", true)
	if _area_recogida:
		_area_recogida.set_deferred("monitoring", false)

	queue_free()

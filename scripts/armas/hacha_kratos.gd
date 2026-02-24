extends ArmaMeleeBase

const TEXTURA_SUELO: Texture2D = preload("res://assets/sprites/armas/Hacha_Kratos/Hacha_normal_Kratos.png")
const TEXTURA_MANO: Texture2D = preload("res://assets/sprites/armas/Hacha_Kratos/Hacha_efecto_Kratos.png")

# Configura valores del hacha
func _ready() -> void:
	dano = 2
	velocidad_ataque = 0.55
	knockback = Vector2(300, -100)
	nombre_animacion_ataque = "atacar"
	super._ready()

# Cambia sprite al equipar
func _al_equipar() -> void:
	super._al_equipar()
	$Sprite2D.texture = TEXTURA_MANO

# Restaura sprite al soltar
func _al_soltar() -> void:
	super._al_soltar()
	$Sprite2D.texture = TEXTURA_SUELO

# Ejecuta el ataque
func atacar() -> void:
	super.atacar()

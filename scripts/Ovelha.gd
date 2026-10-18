extends CharacterBody2D

# =====================================================================
# OVELHA — anda sozinha pelo mapa só pra dar vida ao cenário.
#
# Ela NÃO tem interação nenhuma com o jogador: não dá pra pegar, não
# bloqueia a passagem, não faz nada. É decoração que se mexe.
#
# Como ela pensa (bem simples de propósito, isso é uma Jam):
#
#   PARADA  --(acabou o tempo)--> sorteia um ponto perto de "casa"
#   ANDANDO --(chegou)----------> para e descansa
#   ANDANDO --(travou)----------> desiste e sorteia outro ponto
#
# "Casa" é onde ela nasceu: ela só passeia num raio em volta daquele
# ponto, então nunca se perde pelo mapa nem fica presa num canto.
# =====================================================================


# =====================================================================
# O QUE DÁ PRA AJUSTAR NO INSPECTOR (por ovelha)
# =====================================================================

## Quantos pixels por segundo ela anda (baixo de propósito: ovelha pastando)
@export var velocidade: float = 22.0

## Até que distância de onde ela nasceu ela aceita passear
@export var raio_de_passeio: float = 120.0

## Quantos segundos ela fica parada entre um passeio e outro
@export var tempo_parada: float = 3.0


# =====================================================================
# REGRAS FIXAS (iguais pra todas as ovelhas)
# =====================================================================

## A partir desta distância (em pixels) ela considera que chegou
const DISTANCIA_DE_CHEGADA: float = 4.0

## De quanto em quanto tempo ela confere se ainda está conseguindo andar
const TEMPO_DE_TESTE: float = 1.0

## Se andou menos que esta fração do esperado no tempo de teste, é
## porque tem árvore/pedra na frente -> desiste do destino.
const MINIMO_ESPERADO: float = 0.25


# =====================================================================
# ESTADO
# =====================================================================

# Onde ela nasceu (centro da área de passeio)
var ponto_de_casa: Vector2

# Pra onde ela está indo agora
var destino: Vector2

# Ela está andando ou parada?
var andando: bool = false

var _posicao_anterior: Vector2
var _tempo_do_teste: float = 0.0
var _distancia_do_teste: float = 0.0

@onready var animacao: AnimatedSprite2D = $Animacao
@onready var timer_passeio: Timer = $TimerPasseio


func _ready() -> void:
	ponto_de_casa = global_position
	_posicao_anterior = global_position

	# Jogador e ovelha se ignoram. Fica aqui, e não no Main, porque é um
	# detalhe DA ovelha (o Main não precisa saber que ela existe).
	# O jogador já está na árvore e no grupo quando este código roda:
	# a cena inteira entra na árvore antes de qualquer _ready rodar.
	var jogador: Node = get_tree().get_first_node_in_group("jogador")
	if jogador != null:
		add_collision_exception_with(jogador)
		jogador.add_collision_exception_with(self)

	timer_passeio.timeout.connect(_escolher_destino)

	# Cada ovelha começa num tempo sorteado, senão todas saem andando no
	# mesmo instante e fica robótico (dá pra ver que é script).
	timer_passeio.start(randf_range(0.3, tempo_parada))


func _physics_process(delta: float) -> void:
	if not andando:
		return

	var ate_o_destino: Vector2 = destino - global_position
	if ate_o_destino.length() <= DISTANCIA_DE_CHEGADA:
		_parar()
		return

	velocity = ate_o_destino.normalized() * velocidade
	move_and_slide()

	# Vira o sprite pro lado que está indo
	if absf(velocity.x) > 0.01:
		animacao.flip_h = velocity.x < 0.0

	_conferir_se_travou(delta)


# Ela mandou velocidade mas não saiu do lugar? Então tem algo na frente.
# Compara o quanto ela REALMENTE andou com o quanto DEVERIA ter andado
# no mesmo intervalo de tempo (por isso o teste é por intervalo e não
# por frame: medir 0,3 pixel por frame daria erro de arredondamento).
func _conferir_se_travou(delta: float) -> void:
	_distancia_do_teste += global_position.distance_to(_posicao_anterior)
	_posicao_anterior = global_position
	_tempo_do_teste += delta

	if _tempo_do_teste < TEMPO_DE_TESTE:
		return

	var esperado: float = velocidade * _tempo_do_teste
	if _distancia_do_teste < esperado * MINIMO_ESPERADO:
		_parar()
		timer_passeio.start(0.4)  # pensa rapidinho e já tenta outro lugar
	_tempo_do_teste = 0.0
	_distancia_do_teste = 0.0


# Sorteia um ponto pra passear e começa a ir pra lá.
# O mínimo de 35% do raio evita ela escolher um destino colado nela
# mesma (o que seria um "passinho" esquisito).
func _escolher_destino() -> void:
	var direcao: Vector2 = Vector2.RIGHT.rotated(randf() * TAU)
	destino = ponto_de_casa + direcao * randf_range(raio_de_passeio * 0.35, raio_de_passeio)
	andando = true
	_tempo_do_teste = 0.0
	_distancia_do_teste = 0.0
	animacao.play("andando")


# Chegou (ou desistiu): para, volta pra animação de parada e descansa.
# O tempo de descanso é sorteado pra as ovelhas não sincronizarem.
func _parar() -> void:
	andando = false
	velocity = Vector2.ZERO
	animacao.play("parado")
	timer_passeio.start(tempo_parada * randf_range(0.6, 1.5))

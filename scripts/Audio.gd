class_name Audio
extends Node

# =====================================================================
# ÁUDIO — o som do MUNDO (o que não pertence a nenhum bicho específico).
#
# Mora aqui:
#   - a ambiência do dia (vento) e da noite (insetos), com crossfade;
#   - o pacote do PÂNICO, que acompanha a sanidade em escadinha:
#       respiração (já no limite da tela: 60%)  -> severidade 0.0
#       coração    (~35% de sanidade)           -> severidade 0.42
#       tempestade (~20% de sanidade)           -> severidade 0.67
#
# NÃO mora aqui o som preso a um bicho: os passos do John são do Player e o
# berro é da Ovelha (cada um cuida do seu). Eles tocam no bus "Efeitos",
# que este nó liga/desliga nas cenas (a abertura, o dormir).
#
# Quem manda aqui é a MAIN: ela é a dona do fluxo (sabe que anoiteceu, que
# o jogador dormiu, que a sanidade caiu). Este nó só obedece — a mesma
# divisão de trabalho da SanidadeVisual (call down, signal up).
# =====================================================================


# =====================================================================
# OS CLIPES
# =====================================================================
# Todos foram "ouvidos" pelo envelope do próprio arquivo (medindo volume ao
# longo do tempo), e isso mudou como cada um é usado:
#   - PassoGrama (4,7s) NÃO é um passo: é um ciclo contínuo de passos, sem
#     silêncio no meio. Ele toca EM LOOP enquanto anda (ver Player.gd).
#   - Trovao (60s) NÃO é um trovão: é uma tempestade inteira, com estouros
#     espalhados (0,3s / 13s / 20s / 33s / 52s...) e muito silêncio. Daí
#     ele ser uma CAMA que liga com o pânico: os "trovões de vez em quando"
#     já estão dentro do arquivo.
#   - BatidaCoracao (1,0s) e RepiracaoPesada (1,0s): um ciclo completo cada
#     (um lub-dub e uma respiração) -> loop perfeito, e dá pra acelerar com
#     pitch_scale conforme a cabeça piora.
const VENTO: AudioStream = preload("res://assets/audios/VentoArvores.mp3")            # 120s
const INSETOS: AudioStream = preload("res://assets/audios/InsetosNoite.mp3")          # 131s
const TEMPESTADE: AudioStream = preload("res://assets/audios/Trovao.mp3")             # 60s
const CORACAO: AudioStream = preload("res://assets/audios/BatidaCoracao.mp3")         # 1,0s
const RESPIRACAO: AudioStream = preload("res://assets/audios/RepiracaoPesada.mp3")    # 1,0s

const BUS_EFEITOS: String = "Efeitos"

# A escadinha do pânico na régua da Main (severidade: 0 = sanidade nos 60%,
# 1 = sanidade no zero). Os valores têm comentário em cima; se mexer nesta
# régua, confira que a conta da Main continua batendo (ver
# LIMITE_SANIDADE_TELA, no Main.gd).
const SEV_CORACAO: float = 0.42
const SEV_TEMPESTADE: float = 0.67

# Quanto de severidade cada camada leva pra entrar de vez. Sem esta rampa,
# ela estalaria de mudo pra alto no primeiro centésimo de sanidade.
const RAMPA_DA_RESPIRACAO: float = 0.20
const RAMPA_DO_CORACAO: float = 0.18
const RAMPA_DA_TEMPESTADE: float = 0.18


# =====================================================================
# O QUE DÁ PRA AJUSTAR NO INSPECTOR (ao vivo, com o jogo rodando)
# =====================================================================
# Os clipes têm volumes MUITO diferentes entre si (medido: o vento tem pico
# 0.03, os insetos 0.12, o trovão 0.44). Por isso estes números não parecem
# "bonitos": eles existem pra deixar tudo no mesmo nível de orelha.
@export var volume_vento_db: float = -4.0
@export var volume_insetos_db: float = -12.0
@export var volume_respiracao_db: float = -6.0
@export var volume_coracao_db: float = -6.0
@export var volume_tempestade_db: float = -8.0

## Duração do crossfade dia <-> noite (o céu leva 4s pra fechar: casa com ele)
@export var tempo_do_crossfade: float = 4.0

## Duração do fade geral (dormir, game over)
@export var tempo_do_silencio: float = 1.5


# =====================================================================
# ESTADO
# =====================================================================
# Quanto do VENTO está soando: 1 = dia, 0 = noite. O crossfade é este número
# caminhando — os insetos são o (1 - isto).
# Ele nasce em 1 (dia) porque é assim que o jogo começa. Quem faz o "som
# entrando devagar" na abertura é o _geral logo abaixo (nasce em 0 e a Main
# manda ele subir quando a pálpebra abre).
var _peso_do_dia: float = 1.0
var _alvo_do_dia: float = 1.0

# 1 = som ligado, 0 = silêncio de CENA (dormir/game over). Multiplica tudo.
var _geral: float = 0.0
var _alvo_geral: float = 1.0

# A severidade da sanidade, mandada pela Main a cada frame.
var _severidade: float = 0.0

@onready var vento: AudioStreamPlayer = $VentoArvores
@onready var insetos: AudioStreamPlayer = $InsetosNoite
@onready var tempestade: AudioStreamPlayer = $Tempestade
@onready var coracao: AudioStreamPlayer = $Coracao
@onready var respiracao: AudioStreamPlayer = $Respiracao


func _ready() -> void:
	# Os mp3 vêm importados com loop=false (é o padrão do importador).
	# Marcar o loop AQUI é de propósito: o loop é uma decisão deste nó, não
	# do arquivo — e assim não precisa reimportar nem reabrir o editor.
	for clipe in [VENTO, INSETOS, TEMPESTADE, CORACAO, RESPIRACAO]:
		(clipe as AudioStreamMP3).loop = true

	vento.stream = VENTO
	insetos.stream = INSETOS
	tempestade.stream = TEMPESTADE
	coracao.stream = CORACAO
	respiracao.stream = RESPIRACAO

	# O bus dos efeitos pode ter ficado MUDO no game over anterior (o mute
	# do AudioServer é global e sobrevive ao reload da cena). Zera aqui.
	definir_efeitos_ligados(true)


func _process(delta: float) -> void:
	# As duas rampas de estado. move_toward = sem tween pra gerenciar (e se a
	# Main mudar de ideia no meio, é só mudar o alvo).
	_peso_do_dia = move_toward(_peso_do_dia, _alvo_do_dia, delta / maxf(tempo_do_crossfade, 0.01))
	_geral = move_toward(_geral, _alvo_geral, delta / maxf(tempo_do_silencio, 0.01))
	_aplicar_volumes()


# =====================================================================
# O QUE A MAIN MANDA
# =====================================================================
# De dia: vento. É também o "volta ao normal" depois de uma cena (devolve o
# som geral e reabre os efeitos: passos, berros).
func ir_para_o_dia() -> void:
	_alvo_do_dia = 1.0
	_alvo_geral = 1.0
	definir_efeitos_ligados(true)


# Anoiteceu: o vento sai e os insetos entram (leva tempo_do_crossfade).
func ir_para_a_noite() -> void:
	_alvo_do_dia = 0.0
	_alvo_geral = 1.0
	definir_efeitos_ligados(true)


# Silêncio de CENA: dormir e game over. Some TUDO — inclusive os passos e os
# berros, que não são deste nó: é a diferença entre "escureceu" e "acabou".
func calar() -> void:
	_alvo_geral = 0.0
	definir_efeitos_ligados(false)


# Efeitos = passos do Player + berros das ovelhas (bus "Efeitos"). Numa cena
# eles ficam mudos: o John de olhos fechados não sai andando, e uma ovelha
# berrando no escuro entregaria que o mundo continua ali.
func definir_efeitos_ligados(ligados: bool) -> void:
	var idx: int = AudioServer.get_bus_index(BUS_EFEITOS)
	if idx < 0:
		return
	AudioServer.set_bus_mute(idx, not ligados)


# A sanidade na voz do mundo: 0 = cabeça calma, 1 = cabeça no limite.
func definir_panico(severidade: float) -> void:
	_severidade = clampf(severidade, 0.0, 1.0)


# =====================================================================
# O CÁLCULO DOS VOLUMES (roda a cada frame)
# =====================================================================
func _aplicar_volumes() -> void:
	# As três camadas do pânico, em rampa (smoothstep = entra macio)
	var respiracao_ligada: float = smoothstep(0.0, RAMPA_DA_RESPIRACAO, _severidade)
	var coracao_ligado: float = smoothstep(SEV_CORACAO, SEV_CORACAO + RAMPA_DO_CORACAO, _severidade)
	var tempestade_ligada: float = smoothstep(SEV_TEMPESTADE, SEV_TEMPESTADE + RAMPA_DA_TEMPESTADE, _severidade)

	# Ambiências (o crossfade dia/noite)
	_tocar(vento, volume_vento_db, _peso_do_dia * _geral)
	_tocar(insetos, volume_insetos_db, (1.0 - _peso_do_dia) * _geral)

	# O pânico
	_tocar(respiracao, volume_respiracao_db, respiracao_ligada * _geral)
	_tocar(coracao, volume_coracao_db, coracao_ligado * _geral)
	_tocar(tempestade, volume_tempestade_db, tempestade_ligada * _geral)

	# E o coração acelera conforme a cabeça piora: é a diferença entre uma
	# respiração preocupada e um ataque de pânico de verdade.
	coracao.pitch_scale = lerpf(1.0, 1.45, coracao_ligado)
	respiracao.pitch_scale = lerpf(1.0, 1.30, respiracao_ligada)


# Liga/desliga o player pelo FATOR (e não pelo volume): som parado não
# decodifica. E todo player volta do ZERO — o coração sempre entra no
# primeiro baque, nunca no meio de um ciclo.
#
# ATENÇÃO: `playing = true` num player que JÁ está tocando chama play() de
# novo (reinicia o stream!) — por isso o estado só é tocado quando muda de
# verdade. Sem esta linha, o vento reiniciaria a cada frame: som travado no
# primeiro milissegundo do clipe e um vazamento de playbacks por frame.
func _tocar(player: AudioStreamPlayer, volume_base_db: float, fator: float) -> void:
	fator = clampf(fator, 0.0, 1.0)

	var quer_tocar: bool = fator > 0.0001
	if quer_tocar != player.playing:
		player.playing = quer_tocar

	if quer_tocar:
		player.volume_db = volume_base_db + linear_to_db(fator)


# Na saída do jogo, cala os players: um playback vivo na hora do desligamento
# vira "instance leaked at exit" no console do Godot (sujeira de diagnóstico,
# não bug de jogo — mas sujeira que esconde bug de verdade depois).
func _exit_tree() -> void:
	for player in [vento, insetos, tempestade, coracao, respiracao]:
		player.stop()

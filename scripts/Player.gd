extends CharacterBody2D


@export var velocidade: float = 100.0

signal inventario_alterado(slot_index: int, item_name: String)

# O Player só PEDE pra dormir; quem executa é a Main (dona do ciclo dia/noite).
# "call down, signal up": o Player nunca chama a Main diretamente.
signal dormir_solicitado

# Mesma ideia pra conversa: o Player só diz COM QUEM o jogador quer falar.
# Quem escolhe a fala do dia (e manda a HUD mostrar) é a Main, que é a dona
# do dia_atual.
signal conversa_solicitada(npc: NPC)

# Idem pro barco: o Player só diz QUE o jogador quer entregar material.
# Quem desconta o inventário é a Main (dona do fluxo) e quem sabe quanto
# falta é o próprio Barco.
signal barco_solicitado(barco: Barco)

# Dica rápida pro HUD ("Aperte E para...") quando algo entra no alcance
signal dica_interacao(texto: String)

#direcao
var ultima_direcao: Vector2 = Vector2.DOWN

#inventario
var inventario: Array[String] = ["", "", ""]

# Enquanto true (modo de construção ativo no Main), o E não pega item
var modo_construcao: bool = false

# Enquanto true, o jogador está DENTRO de uma conversa: não anda e o E não
# interage (nesse momento o E é da Main, que avança a fala).
var conversando: bool = false

# Enquanto true, o jogador está dentro de uma CENA (a vinheta de dormir, o
# cartão de história). Trava igual à conversa, pelo mesmo motivo: nada de
# sair andando no escuro nem de o E do cartão pegar um item do chão.
var em_cena: bool = false

@onready var area_interacao: Area2D = $AreaInteracao
@onready var item_proximo: Item = null

# Área da casa (grupo "abrigo") ao alcance do jogador, se houver
var casa_proxima: Area2D = null

# Barco ao alcance, se houver (é o pai da AreaBarco que entrou na minha área)
var barco_proximo: Barco = null

# NPC ao alcance, se houver (é o pai da AreaConversa que entrou na minha área)
var npc_proximo: NPC = null
@onready var animacao: AnimatedSprite2D = $AnimatedSprite2D  # Referência ao nó de animação

# =====================================================================
# PASSOS NA GRAMA
# =====================================================================
# O PassoGrama.mp3 (4,7s) NÃO é "um passo": é um ciclo CONTÍNUO de passos na
# grama — dá pra ver no envelope do próprio arquivo que não existe silêncio
# entre as batidas. Então ele não é disparado a cada passo: fica tocando EM
# LOOP enquanto o John anda, e quem trabalha é o VOLUME (acende rápido,
# apaga devagar). Sem stop/play a cada passo não tem corte seco no ciclo.
const PASSOS: AudioStream = preload("res://assets/audios/PassoGrama.mp3")

const VOLUME_PASSOS_MUDO_DB: float = -80.0
const SUBIDA_DOS_PASSOS_DB_S: float = 400.0   # liga em ~0,23s
const DESCIDA_DOS_PASSOS_DB_S: float = 55.0   # apaga em ~1,7s

@onready var passos: AudioStreamPlayer = $Passos

## Volume dos passos com o John andando. O clipe é MUITO baixo por natureza
## (pico 0.017): daí este valor positivo. Dá pra ajustar ao vivo no Inspector.
@export var volume_passos_db: float = 12.0

# Chão firme = tem tile da camada "Terra". Quem aponta a camada é a Main
# (dona do mapa), no _ready dela. Sem camada, os passos assumem que é chão.
var camada_do_chao: TileMapLayer = null


func _ready() -> void:
	# Loop marcado em CÓDIGO: os mp3 foram importados com loop=false, e
	# marcar aqui não exige reimportar nem reabrir o editor (ver Audio.gd).
	(PASSOS as AudioStreamMP3).loop = true
	passos.stream = PASSOS
	passos.volume_db = VOLUME_PASSOS_MUDO_DB
	passos.play()


func _physics_process(delta: float) -> void:
	#movimentação
	
	var direcao: Vector2 = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")

	# Numa conversa (ou numa cena) o jogador fica preso no lugar. Como a
	# direção vira zero, ele continua na animação de parado — ou seja, segue
	# "respirando" enquanto ouve o NPC.
	if conversando or em_cena:
		direcao = Vector2.ZERO

# 2. Aplica movimento SE NÃO ESTAMOS NO MEIO DE UMA ANIMAÇÃO DE COLETA
	if direcao != Vector2.ZERO and animacao.animation != "coletando item":
		ultima_direcao = direcao
	
		velocity = direcao * velocidade
		move_and_slide()
		
		# 3. Troca animação baseado na direção dominante
		_atualizar_animacao(direcao)
	else:
		# 4. Se não estiver se movendo OU se estiver coletando, trata o parado
		#    Só atualiza para animação parado se NÃO estivermos coletando
		if animacao.animation != "coletando item":
			velocity = Vector2.ZERO
			move_and_slide()
		
			_atualizar_animacao_parado()
	
	# --- Os passos: com o pé no chão e andando de verdade ---
	# (a mesma condição do movimento lá em cima: quem está "coletando item"
	#  fica parado, então também não faz barulho de passo)
	var andando: bool = direcao != Vector2.ZERO and animacao.animation != "coletando item"
	_atualizar_passos(andando, delta)

	if Input.is_action_just_pressed("interagir") and not modo_construcao and not conversando and not em_cena:
		_tentar_interagir()
		

func _atualizar_animacao(direcao: Vector2) -> void:
	if abs(direcao.x) > abs(direcao.y):
		if direcao.x > 0:
			animacao.animation = "andando lado"
			animacao.flip_h = (direcao.x < 0)
		else:
			animacao.animation = "andando lado"
			animacao.flip_h = (direcao.x < 0)
	else:
		if direcao.y > 0:
			animacao.animation = "andando frente"
			
		else:
			animacao.animation = "andando costa"
	
	if not animacao.is_playing():
		animacao.play()
		
func _atualizar_animacao_parado() -> void:
	"""Define a animação de idle baseado na última direção de movimento"""
	# Mapeia a última direção para a animação parado correspondente
	if abs(ultima_direcao.x) > abs(ultima_direcao.y):  # Último movimento foi horizontal
		if ultima_direcao.x > 0:  # Último movimento foi para a direita
			animacao.animation = "parado"
		else:  # Último movimento foi para a esquerda
			animacao.animation = "parado"
	else:  # Último movimento foi vertical (cima/baixo)
		if ultima_direcao.y > 0:  # Último movimento foi para baixo
			animacao.animation = "parado"
		else:  # Último movimento foi para cima
			animacao.animation = "parado costa"  # << ESSE É O QUE VOCÊ QUER!
	
	# Garante que a animação parado toque
	if not animacao.is_playing():
		animacao.play()

#item na area de interação do jogador
func _on_area_interacao_area_entered(area: Area2D) -> void:
	if area.is_in_group("item"):
		item_proximo = area as Item
		# Dica na tela pra ficar claro o que o E faz
		if item_proximo != null:
			dica_interacao.emit("Aperte E para pegar " + item_proximo.nome_do_item)
	elif area.is_in_group("abrigo"):
		casa_proxima = area
		dica_interacao.emit("Aperte E para dormir")
	elif area.is_in_group("npc"):
		# Quem entra na minha área é a AreaConversa do NPC; o NPC em si é o
		# pai dela (é onde ficam a chave da fala e o nome mostrado).
		npc_proximo = area.get_parent() as NPC
		if npc_proximo != null:
			dica_interacao.emit("Aperte E para falar com " + npc_proximo.nome_mostrado)
	elif area.is_in_group("barco"):
		# Mesma ideia do NPC: a AreaBarco é filha do Barco. Aqui a dica muda
		# conforme o John tem (ou não) material pra entregar — é o "dá pra
		# interagir" que o jogador precisa ver antes de apertar E.
		barco_proximo = area.get_parent() as Barco
		if barco_proximo != null:
			if quantos_do_tipo("madeira") > 0 or quantos_do_tipo("pedra") > 0:
				dica_interacao.emit("Aperte E para entregar material ao barco")
			else:
				dica_interacao.emit("O barco precisa de madeira e pedra")

#saiu
func _on_area_interacao_area_exited(area: Area2D) -> void:
	if area == item_proximo:
		item_proximo = null
	elif area == casa_proxima:
		casa_proxima = null
	elif npc_proximo != null and area.get_parent() == npc_proximo:
		npc_proximo = null
	elif barco_proximo != null and area.get_parent() == barco_proximo:
		barco_proximo = null

# O E é uma tecla só, então ela precisa escolher entre os alvos que estão ao
# mesmo tempo ao alcance: pegar o item, dormir na casa ou conversar com um NPC.
# Regra: quem estiver MAIS PERTO ganha. Assim um item que caia dentro da área
# da casa continua pegável (senão ficaria preso ali dentro pra sempre).
func _tentar_interagir() -> void:
	# Junta os candidatos: cada um é { "no": nó, "dist": distância até ele }
	var candidatos: Array[Dictionary] = []
	if item_proximo != null:
		candidatos.append({ "no": item_proximo, "dist": global_position.distance_to(item_proximo.global_position) })
	if casa_proxima != null:
		candidatos.append({ "no": casa_proxima, "dist": global_position.distance_to(casa_proxima.global_position) })
	if npc_proximo != null:
		candidatos.append({ "no": npc_proximo, "dist": global_position.distance_to(npc_proximo.global_position) })
	if barco_proximo != null:
		candidatos.append({ "no": barco_proximo, "dist": global_position.distance_to(barco_proximo.global_position) })

	if candidatos.is_empty():
		return

	var escolhido: Dictionary = candidatos[0]
	for candidato in candidatos:
		if candidato["dist"] < escolhido["dist"]:
			escolhido = candidato

	var alvo: Node = escolhido["no"]
	if alvo == item_proximo:
		pegar_item(item_proximo)
	elif alvo == casa_proxima:
		# Não chama a Main: só avisa que o jogador quer dormir
		dormir_solicitado.emit()
	elif alvo == barco_proximo:
		# Idem: só avisa que ele quer entregar material; a Main desconta
		barco_solicitado.emit(barco_proximo)
	else:
		# Idem: só avisa COM QUEM ele quer falar; a fala do dia é da Main
		conversa_solicitada.emit(npc_proximo)

#tentar adicinoar item no inventario
func pegar_item(item: Item) -> void:
	var nome_item: String = item.nome_do_item
	
	#procura slot
	for i in inventario.size():
		if inventario[i] == "":
			inventario[i] = nome_item
			
			animacao.animation = "coletando item"
			animacao.play()
			
			item.esconder()
			item_proximo = null
			
			emit_signal("inventario_alterado", i, nome_item)  # ← ISSO AQUI
			
			return

func _on_Animacao_animation_finished() -> void:
	# Só reagimos se a animação que acabou de terminar for a de coleta
	if animacao.animation == "coletando item":
		# Restaura a velocidade normal se você estiver usando speed_scale (opcional)
		# animacao.speed_scale = velocidade_original  # ← Descomente se ajustou velocidade anteriormente
		
		# Volta à animação apropriada baseada no movimento atual
		var direcao: Vector2 = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
		if direcao != Vector2.ZERO:
			_atualizar_animacao(direcao)  # Volta à animação de movimento
		else:
			_atualizar_animacao_parado()  # Volta à animação parado


# =====================================================================
# INVENTÁRIO — usado pela construção (Main) para checar e gastar itens
# =====================================================================
# Quantos itens deste tipo estão na mochila? (ex: quantos_do_tipo("madeira"))
func quantos_do_tipo(nome: String) -> int:
	var total: int = 0
	for i in inventario.size():
		if inventario[i] == nome:
			total += 1
	return total

# Tira ATÉ "limite" itens deste tipo da mochila e devolve quantos saíram.
# É o que o barco usa: o jogador entrega tudo o que tem de madeira/pedra de
# uma vez, em vez de 1 por aperto (a mochila só tem 3 slots, e o barco pede
# 30 itens — um por E seriam 30 apertos).
func retirar_itens_do_tipo(nome: String, limite: int) -> int:
	var tirados: int = 0
	for i in inventario.size():
		if tirados >= limite:
			break
		if inventario[i] == nome:
			inventario[i] = ""
			inventario_alterado.emit(i, "")
			tirados += 1
	return tirados

# Diz se o jogador tem TODOS os itens da lista (contando itens repetidos).
# Ex: tem_itens(["madeira", "madeira"]) só é true se houver 2 madeiras.
func tem_itens(necessarios: Array) -> bool:
	var usados: Array[bool] = []
	usados.resize(inventario.size())

	for item_necessario in necessarios:
		var achou: bool = false
		for i in inventario.size():
			if not usados[i] and inventario[i] == item_necessario:
				usados[i] = true
				achou = true
				break
		if not achou:
			return false
	return true

# Gasta os itens da lista (se tiver todos). Retorna false se faltar algo.
func consumir_itens(necessarios: Array) -> bool:
	if not tem_itens(necessarios):
		return false

	var usados: Array[bool] = []
	usados.resize(inventario.size())

	for item_necessario in necessarios:
		for i in inventario.size():
			if not usados[i] and inventario[i] == item_necessario:
				usados[i] = true
				inventario[i] = ""
				emit_signal("inventario_alterado", i, "")  # HUD limpa o slot
				break
	return true

# Usa o item de um slot (hoje: comer). O efeito vem do CatalogoItens, então
# um item novo com efeito não precisa mexer neste código.
# Retorna false se o slot está vazio ou se o item não tem utilidade.
func usar_item(slot_index: int) -> bool:
	if slot_index < 0 or slot_index >= inventario.size():
		return false

	var nome: String = inventario[slot_index]
	if nome == "" or not CatalogoItens.pode_usar(nome):
		return false

	# Aplica os efeitos declarados no catálogo (ex: comida -> { "fome": 50 })
	var efeito: Dictionary = CatalogoItens.efeitos(nome)
	if efeito.has("fome"):
		Status.mudar_fome(efeito["fome"])
	if efeito.has("vida"):
		Status.mudar_vida(efeito["vida"])
	if efeito.has("sanidade"):
		Status.mudar_sanidade(efeito["sanidade"])

	# Consumiu: o slot esvazia e a HUD se atualiza pelo sinal
	inventario[slot_index] = ""
	inventario_alterado.emit(slot_index, "")
	return true

# Tira o item de um slot SEM usar ele — é o "largar no chão" (Q).
# O Player só devolve o NOME: quem cria o item no mundo é a Main, que é a
# dona do mapa (mesma regra do dormir e da conversa: signal up).
# Devolve "" se o slot estava vazio (aí nada acontece).
func tirar_item(slot_index: int) -> String:
	if slot_index < 0 or slot_index >= inventario.size():
		return ""

	var nome: String = inventario[slot_index]
	if nome == "":
		return ""

	inventario[slot_index] = ""
	inventario_alterado.emit(slot_index, "")
	return nome


# =====================================================================
# PASSOS: o volume caminha devagar até o alvo
# =====================================================================
# O volume sobe RÁPIDO (o jogador começou a andar: o som tem que aparecer)
# e desce DEVAGAR (parou: a grama vai morrendo em vez de cortar no meio de
# um passo). Não é tween porque não existe estado pra gerenciar — é só um
# número que anda um pouco por frame, na direção do alvo.
func _atualizar_passos(andando: bool, delta: float) -> void:
	var alvo: float = VOLUME_PASSOS_MUDO_DB
	if andando and _sobre_o_chao():
		alvo = volume_passos_db

	var velocidade_db_s: float = SUBIDA_DOS_PASSOS_DB_S if alvo > passos.volume_db else DESCIDA_DOS_PASSOS_DB_S
	passos.volume_db = move_toward(passos.volume_db, alvo, velocidade_db_s * delta)


# "Chão firme" = a célula debaixo do John tem tile na camada Terra.
# Isso existe porque a água não tem colisão (bug conhecido e aceito): o John
# consegue andar por cima do mar, e passo de GRAMA dentro do mar soa errado.
func _sobre_o_chao() -> bool:
	if camada_do_chao == null:
		return true
	return camada_do_chao.get_cell_source_id(camada_do_chao.local_to_map(global_position)) != -1


# Na saída do jogo, cala o player: playback vivo na hora do desligamento vira
# "instance leaked at exit" no console do Godot (sujeira de diagnóstico).
func _exit_tree() -> void:
	passos.stop()

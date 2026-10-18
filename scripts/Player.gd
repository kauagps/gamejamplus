extends CharacterBody2D


@export var velocidade: float = 100.0

signal inventario_alterado(slot_index: int, item_name: String)

# O Player só PEDE pra dormir; quem executa é a Main (dona do ciclo dia/noite).
# "call down, signal up": o Player nunca chama a Main diretamente.
signal dormir_solicitado

# Dica rápida pro HUD ("Aperte E para...") quando algo entra no alcance
signal dica_interacao(texto: String)

#direcao
var ultima_direcao: Vector2 = Vector2.DOWN

#inventario
var inventario: Array[String] = ["", "", ""]

# Enquanto true (modo de construção ativo no Main), o E não pega item
var modo_construcao: bool = false

@onready var area_interacao: Area2D = $AreaInteracao
@onready var item_proximo: Item = null
@onready var animacao: AnimatedSprite2D = $AnimatedSprite2D  # Referência ao nó de animação

func _physics_process(delta: float) -> void:
	#movimentação
	
	var direcao: Vector2 = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")

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
	
	if Input.is_action_just_pressed("interagir") and item_proximo != null and not modo_construcao:
		pegar_item(item_proximo)
		

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

#saiu
func _on_area_interacao_area_exited(area: Area2D) -> void:
	if area == item_proximo:
		item_proximo = null

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

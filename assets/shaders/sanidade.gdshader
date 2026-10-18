shader_type canvas_item;

// =====================================================================
// SANIDADE — a tela "adoece" conforme a cabeca do John falha.
//
// Ele roda num ColorRect que cobre a tela inteira. Em vez de PINTAR por
// cima, ele LE o que ja foi desenhado embaixo (hint_screen_texture) e
// redesenha com tres estragos, todos crescendo com a "intensidade":
//
//   1) ESCURECER AS BORDAS -> a visao fecha em volta (efeito tunel)
//   2) ONDULAR a imagem    -> o mundo "respira" torto
//   3) GRANULADO           -> a imagem fica suja, picotada
//
// Quem manda a intensidade e a Main (0 = cabeca boa, 1 = a beira da morte).
// Regra do projeto: este shader nao decide nada, ele so desenha.
// =====================================================================

// A tela do jogo ja desenhada (o que esta "atras" deste retangulo)
uniform sampler2D tela : hint_screen_texture, repeat_disable, filter_linear;

// 0.0 = cabeca sa (nao acontece nada) ... 1.0 = sanidade zerando
uniform float intensidade : hint_range(0.0, 1.0) = 0.0;

// So serve pra animar (a Main empurra o tempo de jogo pra ca)
uniform float tempo = 0.0;

// Ruido barato (nao precisa ser bom: e pra parecer ERRADO, nao bonito)
float ruido(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec2 uv = SCREEN_UV;

	// 1) ONDULACAO: duas senoides em eixos diferentes, pra imagem nao
	//    ondular "em bloco" (fica mais organico, mais errado).
	float onda_x = sin(uv.y * 26.0 + tempo * 2.6) * 0.0045;
	float onda_y = sin(uv.x * 34.0 - tempo * 2.1) * 0.0032;

	// Respiracao lenta por cima da ondulacao (pulsa de leve, ida e volta)
	float pulso = sin(tempo * 1.4) * 0.5 + 0.5;
	vec2 torto = uv + vec2(onda_x, onda_y) * intensidade * (0.6 + pulso * 0.9);

	// 2) GRANULADO: a "sujeira". Cresce com o quadrado da intensidade,
	//    porque perto da morte ele precisa dar um salto.
	float grao = ruido(uv * vec2(1280.0, 720.0) + vec2(tempo * 41.0, tempo * 67.0));
	torto += (grao - 0.5) * 0.004 * intensidade * intensidade;

	vec3 cor = texture(tela, torto).rgb;

	// 3) TUNEL: escurece do meio pra fora. O CENTRO fica limpo (da pra
	//    jogar); as bordas fecham conforme a intensidade sobe.
	float dist = distance(UV, vec2(0.5));
	float borda = smoothstep(0.18, 0.62, dist);
	cor *= 1.0 - borda * intensidade * 0.92;

	// O que sobra desse escuro ganha um tom "doente" (mais frio, puxado
	// pro verde) e perde um pouco de cor, como vista cansada.
	cor = mix(cor, cor * vec3(0.82, 0.95, 0.86), borda * intensidade);
	float cinza = dot(cor, vec3(0.299, 0.587, 0.114));
	cor = mix(cor, vec3(cinza), borda * intensidade * 0.35);

	COLOR = vec4(cor, 1.0);
}

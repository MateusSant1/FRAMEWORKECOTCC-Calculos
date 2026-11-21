# =====================================================================
# Verificação determinística dos cálculos do TCC
# "Desenvolvimento de Framework de Tomada de Decisão Ecológica para IA
#  Corporativa" (Mateus Henrique de Araújo Santos, UNIT)
#
# Reproduz as Tabelas 4 a 7 do artigo (cenários de classificação,
# cenário logístico, sensibilidade e avaliação consolidada) a partir dos
# dados de entrada publicados nas fontes. Usa apenas R base (sem pacotes).
#
# Como executar: Rscript verificacao_cenarios.R
#   (ou abrir no RStudio / Posit Cloud e clicar em "Source").
# Se todos os valores conferirem com o artigo, a última linha impressa é
#   "VERIFICAÇÃO CONCLUÍDA: todos os valores conferem com o artigo."
# Qualquer divergência interrompe a execução com a mensagem do teste.
# =====================================================================

# ---------------------------------------------------------------------
# 1. Parâmetros comuns (Tabela 3 do artigo)
# ---------------------------------------------------------------------
PUE         <- 1.58    # Safari et al. (2025)
I_REDE      <- 420     # gCO2e/kWh, Nadeem et al. (2026)
H           <- 365     # dias
I_LUCCIONI  <- 297.6   # gCO2e/kWh da região do experimento de Luccioni et al. (2024)
FRAC_QMIN   <- 0.90    # Q_min = 90% da melhor qualidade do cenário
LAMBDAS     <- c(1, 1.5, 2)

# Conversão de emissão medida (g por 1.000 consultas) em energia por
# requisição (Wh): E = (g / 1.000) / I_LUCCIONI  [kWh]  x 1.000  [Wh]
energia_wh <- function(g_por_1000) (g_por_1000 / 1000) / I_LUCCIONI * 1000

# SCI operacional por requisição (Equação 2 do artigo), em gCO2e:
# SCI = E [kWh] x PUE x I
sci_g <- function(e_wh) (e_wh / 1000) * PUE * I_REDE

# Nota menor-é-melhor sobre as alternativas viáveis: melhor / valor
nota <- function(x, viavel) {
  s <- rep(NA_real_, length(x))
  s[viavel] <- min(x[viavel]) / x[viavel]
  s
}

# Índice de Decisão Ecológica (Equação 3 do artigo)
ide <- function(sE, sL, sC, lambda) (lambda * sE + sL + sC) / (lambda + 2)

# Ponto de inversão (Equação 4): X é a mais limpa, Y a outra
lambda_inv <- function(sE_x, P_x, sE_y, P_y) (P_y - P_x) / (sE_x - sE_y)

# Teste com arredondamento: falha se o valor calculado, arredondado,
# diferir do valor publicado no artigo
confere <- function(calculado, esperado, casas, rotulo) {
  ok <- isTRUE(all.equal(round(calculado, casas), esperado, tolerance = 1e-9))
  if (!ok) stop(sprintf("DIVERGÊNCIA em %s: calculado %s, artigo %s",
                        rotulo, paste(round(calculado, casas), collapse = " / "),
                        paste(esperado, collapse = " / ")))
  cat(sprintf("  ok  %-55s %s\n", rotulo, paste(format(round(calculado, casas), nsmall = casas), collapse = " / ")))
}

# ---------------------------------------------------------------------
# 2. Energia por requisição (Seção 4.4)
# ---------------------------------------------------------------------
E_LLM_CLASS  <- energia_wh(4.67)   # BLOOMz-7B em classificação (Luccioni, p. 94)
E_ESP_CLASS  <- energia_wh(0.32)   # BERT de sentimento (Luccioni, p. 94)
E_LLM_MAX    <- 0.42               # maior estimativa para o LLM (Jegham et al., 2025)

cat("\n== Energia por requisição ==\n")
confere(E_LLM_CLASS, 0.01569, 5, "LLM em classificação (Wh/req)")
confere(E_ESP_CLASS, 0.001075, 6, "Modelo específico em classificação (Wh/req)")
confere(sci_g(E_LLM_CLASS), 0.0104, 4, "SCI do LLM (gCO2e/req)")
confere(sci_g(E_ESP_CLASS), 0.0007, 4, "SCI do modelo específico (gCO2e/req)")

# ---------------------------------------------------------------------
# 3. Cenários de classificação (Tabela 4)
#    Dados: Valdes Gonzalez (2026), Tab. 3 (SST-2) e Tab. 4 (AG News)
# ---------------------------------------------------------------------
alternativas <- c("GPT-4o ZS", "GPT-4o FS", "Claude ZS", "Claude FS",
                  "BERT", "RoBERTa", "DistilBERT")
tipo <- c("LLM", "LLM", "LLM", "LLM", "esp", "esp", "esp")

sst2 <- data.frame(
  alt  = alternativas, tipo = tipo,
  f1   = c(87.00, 90.45, 91.78, 94.41, 94.42, 93.59, 93.49),
  p50  = c(377.10, 326.00, 1394.27, 1109.11, 147.03, 133.38, 97.88),
  p95  = c(591.46, 518.82, 2047.78, 1895.08, 192.38, 207.02, 123.93),
  custo = c(192.48, 387.48, 326.67, 599.67, 7.79, 7.07, 5.19),  # US$ por 10^6 req.
  stringsAsFactors = FALSE)

agnews <- data.frame(
  alt  = alternativas, tipo = tipo,
  f1   = c(87.93, 89.65, 91.35, 90.56, 94.43, 94.63, 94.11),
  p50  = c(410.81, 332.31, 1434.82, 1002.56, 196.91, 188.70, 108.19),
  p95  = c(693.55, 582.24, 2298.01, 2544.03, 285.80, 279.20, 161.32),
  custo = c(276.00, 903.50, 440.58, 1271.58, 10.44, 10.00, 5.73),
  stringsAsFactors = FALSE)

avaliar_classificacao <- function(dados, L_sla_ms, frac_qmin = FRAC_QMIN,
                                  e_llm = E_LLM_CLASS) {
  d <- dados
  d$energia <- ifelse(d$tipo == "LLM", e_llm, E_ESP_CLASS)  # FS recebe a energia do ZS
  d$sci <- sci_g(d$energia)
  q_min <- frac_qmin * max(d$f1)
  d$G1 <- d$p95 <= L_sla_ms            # filtro de SLA (latência p95)
  d$G3 <- d$f1 >= q_min                # filtro de qualidade mínima
  d$viavel <- d$G1 & d$G3
  d$sE <- nota(d$sci, d$viavel)
  d$sL <- nota(d$p50, d$viavel)
  d$sC <- nota(d$custo, d$viavel)
  for (l in LAMBDAS) d[[paste0("IDE_", l)]] <- ide(d$sE, d$sL, d$sC, l)
  attr(d, "q_min") <- q_min
  d
}

escolhida <- function(d, lambda = 1.5) {
  v <- d[[paste0("IDE_", lambda)]]
  d$alt[which.max(v)]
}

imprimir <- function(d) {
  cols <- c("alt", "p95", "f1", "G1", "G3", "p50", "custo", "IDE_1", "IDE_1.5", "IDE_2")
  out <- d[order(-ifelse(is.na(d$IDE_1.5), -1, d$IDE_1.5)), cols]
  out[, c("IDE_1", "IDE_1.5", "IDE_2")] <- round(out[, c("IDE_1", "IDE_1.5", "IDE_2")], 3)
  print(out, row.names = FALSE)
}

cat("\n== Cenário financeiro (SST-2; SLA 1 s; D = 10^6/dia) ==\n")
fin <- avaliar_classificacao(sst2, L_sla_ms = 1000)
imprimir(fin)
confere(attr(fin, "q_min"), 85.0, 1, "Q_min financeiro (F1)")
stopifnot(identical(fin$alt[!fin$G1], c("Claude ZS", "Claude FS")), all(fin$G3))
cat("  ok  G1 elimina apenas Claude ZS e Claude FS; G3 não elimina nenhuma\n")
idx <- match(c("DistilBERT", "RoBERTa", "BERT", "GPT-4o FS", "GPT-4o ZS"), fin$alt)
confere(fin$IDE_1[idx],   c(1.000, 0.823, 0.777, 0.127, 0.118), 3, "IDE financeiro, lambda = 1")
confere(fin$IDE_1.5[idx], c(1.000, 0.848, 0.809, 0.119, 0.111), 3, "IDE financeiro, lambda = 1,5")
confere(fin$IDE_2[idx],   c(1.000, 0.867, 0.833, 0.113, 0.106), 3, "IDE financeiro, lambda = 2")
stopifnot(escolhida(fin, 1) == "DistilBERT", escolhida(fin, 1.5) == "DistilBERT",
          escolhida(fin, 2) == "DistilBERT")
confere(fin$sE[fin$alt == "GPT-4o ZS"], 0.069, 3, "Nota de carbono dos LLMs")

x <- fin[fin$alt == "DistilBERT", ]; y <- fin[fin$alt == "GPT-4o ZS", ]
confere(lambda_inv(x$sE, x$sL + x$sC, y$sE, y$sL + y$sC), -1.84, 2,
        "lambda* DistilBERT x GPT-4o ZS (financeiro)")
fin_max <- avaliar_classificacao(sst2, 1000, e_llm = E_LLM_MAX)
confere(fin_max$IDE_1.5[fin_max$alt == "GPT-4o ZS"], 0.083, 3,
        "IDE da baseline com 0,42 Wh (financeiro)")
stopifnot(escolhida(fin_max) == "DistilBERT")

cat("\n== Cenário administrativo (AG News; SLA 3 s; D = 10^5/dia) ==\n")
adm <- avaliar_classificacao(agnews, L_sla_ms = 3000)
imprimir(adm)
confere(attr(adm, "q_min"), 85.2, 1, "Q_min administrativo (F1)")
stopifnot(all(adm$viavel))
cat("  ok  nenhuma alternativa eliminada\n")
ordem <- c("DistilBERT", "RoBERTa", "BERT", "GPT-4o FS", "GPT-4o ZS", "Claude FS", "Claude ZS")
idx <- match(ordem, adm$alt)
confere(adm$IDE_1[idx],   c(1.000, 0.715, 0.699, 0.133, 0.118, 0.060, 0.052), 3, "IDE administrativo, lambda = 1")
confere(adm$IDE_1.5[idx], c(1.000, 0.756, 0.742, 0.124, 0.111, 0.061, 0.055), 3, "IDE administrativo, lambda = 1,5")
confere(adm$IDE_2[idx],   c(1.000, 0.787, 0.775, 0.117, 0.105, 0.062, 0.056), 3, "IDE administrativo, lambda = 2")
stopifnot(escolhida(adm, 1) == "DistilBERT", escolhida(adm, 2) == "DistilBERT")
x <- adm[adm$alt == "DistilBERT", ]; y <- adm[adm$alt == "GPT-4o ZS", ]
confere(lambda_inv(x$sE, x$sL + x$sC, y$sE, y$sL + y$sC), -1.84, 2,
        "lambda* DistilBERT x GPT-4o ZS (administrativo)")
adm_max <- avaliar_classificacao(agnews, 3000, e_llm = E_LLM_MAX)
stopifnot(escolhida(adm_max) == "DistilBERT")
cat("  ok  escolha mantida com a maior estimativa de energia\n")
r <- adm[adm$alt == "RoBERTa", ]; dd <- adm[adm$alt == "DistilBERT", ]
confere(c(r$p50 / dd$p50, r$custo / dd$custo), c(1.7, 1.7), 1,
        "Latência e custo RoBERTa / DistilBERT")
confere(adm$custo[adm$alt == "GPT-4o FS"] / adm$custo[adm$alt == "GPT-4o ZS"], 3.3, 1,
        "Custo GPT-4o FS / ZS")

# ---------------------------------------------------------------------
# 4. Cenário logístico (Tabela 5)
#    Energia: Luccioni et al. (2024), p. 90 (pontas menos favoráveis ao
#    modelo específico: 20 g e 10 g por 1.000 inferências)
# ---------------------------------------------------------------------
ESPERA_MS <- 4 * 3600 * 1000        # 4 h de espera da execução deslocada
RAZAO_LAT <- 410.81 / 108.19        # 3,80: GPT-4o ZS / DistilBERT (AG News)
RAZAO_CUSTO <- 37.1                 # razão de custo medida em classificação
CUSTO_GPT_LOG <- (54 * 2.50 + 11 * 10.00)   # US$ por 10^6 req. (54 e 11 tokens)

avaliar_logistico <- function(r, g_gpt = 20, g_db = 10, e_gpt_wh = NULL,
                              L_sla_ms = 8 * 3600 * 1000) {
  e_gpt <- if (is.null(e_gpt_wh)) energia_wh(g_gpt) else e_gpt_wh
  e_db  <- energia_wh(g_db)
  lat_gpt <- 410.81
  lat_db  <- lat_gpt / RAZAO_LAT
  d <- data.frame(
    alt   = c("GPT-4o imediato", "GPT-4o deslocado", "DistilBART imediato", "DistilBART deslocado"),
    sci   = c(sci_g(e_gpt), sci_g(e_gpt) * (1 - r), sci_g(e_db), sci_g(e_db) * (1 - r)),
    lat   = c(lat_gpt, lat_gpt + ESPERA_MS, lat_db, lat_db + ESPERA_MS),
    custo = c(CUSTO_GPT_LOG, CUSTO_GPT_LOG, CUSTO_GPT_LOG / RAZAO_CUSTO, CUSTO_GPT_LOG / RAZAO_CUSTO),
    stringsAsFactors = FALSE)
  d$viavel <- d$lat <= L_sla_ms       # G1; G3: qualidade aprovada por premissa
  d$sE <- nota(d$sci, d$viavel); d$sL <- nota(d$lat, d$viavel); d$sC <- nota(d$custo, d$viavel)
  for (l in LAMBDAS) d[[paste0("IDE_", l)]] <- ide(d$sE, d$sL, d$sC, l)
  d
}

cat("\n== Cenário logístico (CNN/DailyMail; SLA 8 h; D = 10^4/dia) ==\n")
confere(CUSTO_GPT_LOG, 245, 0, "Custo GPT-4o (US$/10^6 req.)")
confere(CUSTO_GPT_LOG / RAZAO_CUSTO, 6.604, 3, "Custo DistilBART (US$/10^6 req.)")
confere(RAZAO_LAT, 3.80, 2, "Razão de latência usada")
confere(c(energia_wh(20), energia_wh(10)), c(0.0672, 0.0336), 4, "Energia GPT-4o / DistilBART (Wh/req)")
for (rr in c(0.30, 0.70)) {
  cat(sprintf("-- r = %.0f%%\n", rr * 100))
  print(transform(avaliar_logistico(rr)[, c("alt", "sE", "sL", "sC", "IDE_1", "IDE_1.5", "IDE_2")],
                  sE = round(sE, 3), sL = round(sL, 3), sC = round(sC, 3),
                  IDE_1 = round(IDE_1, 3), IDE_1.5 = round(IDE_1.5, 3), IDE_2 = round(IDE_2, 3)),
        row.names = FALSE)
}
l30 <- avaliar_logistico(0.30); l70 <- avaliar_logistico(0.70)
confere(l30$sL, c(0.263, 0.000, 1.000, 0.000), 3, "S^L logístico")
confere(l30$sC, c(0.027, 0.027, 1.000, 1.000), 3, "S^C logístico")
confere(l30$sE, c(0.350, 0.500, 0.700, 1.000), 3, "S^E logístico, r = 30%")
confere(l30$IDE_1.5, c(0.233, 0.222, 0.871, 0.714), 3, "IDE logístico, r = 30%, lambda = 1,5")
confere(l70$sE, c(0.150, 0.500, 0.300, 1.000), 3, "S^E logístico, r = 70%")
confere(l70$IDE_1.5, c(0.147, 0.222, 0.700, 0.714), 3, "IDE logístico, r = 70%, lambda = 1,5")
stopifnot(l30$alt[which.max(l30$IDE_1.5)] == "DistilBART imediato",
          l70$alt[which.max(l70$IDE_1.5)] == "DistilBART deslocado",
          l70$alt[which.max(l70$IDE_2)]   == "DistilBART deslocado",
          l70$alt[which.max(l70$IDE_1)]   == "DistilBART imediato")
cat("  ok  r = 30%: imediato; r = 70%: deslocado (lambda 1,5 e 2); lambda = 1: imediato\n")

# Regra r > 1/lambda: entre as duas execuções do DistilBART, lambda* = 1/r
for (rr in c(0.30, 0.50, 0.70)) {
  d <- avaliar_logistico(rr)
  x <- d[4, ]; y <- d[3, ]
  # a nota de latência da execução deslocada (~7,5e-6) não é exatamente 0,
  # por isso lambda* coincide com 1/r até a segunda casa decimal
  confere(lambda_inv(x$sE, x$sL + x$sC, y$sE, y$sL + y$sC), round(1 / rr, 2), 2,
          sprintf("lambda* deslocado x imediato = 1/r (r = %.0f%%)", rr * 100))
}
# Faixa instável de C3: a escolha difere entre lambda = 1,5 e lambda = 2
instavel <- function(rr) {
  d <- avaliar_logistico(rr)
  d$alt[which.max(d$IDE_1.5)] != d$alt[which.max(d$IDE_2)]
}
rs <- round(seq(0.30, 0.70, by = 0.001), 3)
faixa <- range(rs[sapply(rs, instavel)])
confere(faixa, c(0.500, 0.666), 3, "Faixa em que C3 falha (r)")

# Outra ponta de energia (4 g x 30 g) e maior estimativa (0,42 Wh)
for (rr in c(0.30, 0.70)) {
  a <- avaliar_logistico(rr, g_gpt = 30, g_db = 4)
  b <- avaliar_logistico(rr, e_gpt_wh = E_LLM_MAX)
  stopifnot(grepl("DistilBART", a$alt[which.max(a$IDE_1.5)]),
            grepl("DistilBART", b$alt[which.max(b$IDE_1.5)]))
}
cat("  ok  DistilBART vence com 4 g x 30 g e com 0,42 Wh\n")

# ---------------------------------------------------------------------
# 5. Sensibilidade (Tabela 6)
# ---------------------------------------------------------------------
cat("\n== Sensibilidade ==\n")
# Q_min: maior fração que mantém o DistilBERT
lim_q <- function(dados, sla) {
  best <- max(dados$f1)
  dados$f1[dados$alt == "DistilBERT"] / best
}
confere(floor(lim_q(sst2, 1000) * 1000) / 10, 99.0, 1, "Q_min máximo que mantém DistilBERT (fin, %)")
confere(floor(lim_q(agnews, 3000) * 1000) / 10, 99.4, 1, "Q_min máximo que mantém DistilBERT (adm, %)")
f995 <- avaliar_classificacao(sst2, 1000, frac_qmin = 0.991)
a995 <- avaliar_classificacao(agnews, 3000, frac_qmin = 0.995)
stopifnot(escolhida(f995) %in% c("BERT", "RoBERTa"), escolhida(a995) == "RoBERTa")
cat(sprintf("  ok  acima do limiar: financeiro -> %s; administrativo -> %s\n",
            escolhida(f995), escolhida(a995)))
# SLA: menor SLA que mantém o DistilBERT
confere(ceiling(sst2$p95[sst2$alt == "DistilBERT"]), 124, 0, "SLA mínimo financeiro (ms)")
confere(ceiling(agnews$p95[agnews$alt == "DistilBERT"]), 162, 0, "SLA mínimo administrativo (ms)")
d_sla <- avaliar_logistico(0.70, L_sla_ms = 3.9 * 3600 * 1000)
stopifnot(d_sla$alt[which.max(d_sla$IDE_1.5)] == "DistilBART imediato")
cat("  ok  logístico com SLA < 4 h: só a execução imediata é viável\n")
# PUE, I, D e H: multiplicam todas as alternativas igualmente
base <- escolhida(fin)
for (p in c(1.0, 2.5)) for (ii in c(20, 900)) {
  PUE_old <- PUE; I_old <- I_REDE
  PUE <- p; I_REDE <- ii
  stopifnot(escolhida(avaliar_classificacao(sst2, 1000)) == base,
            escolhida(avaliar_classificacao(agnews, 3000)) == "DistilBERT")
  PUE <- PUE_old; I_REDE <- I_old
}
cat("  ok  PUE e I alteram apenas os totais anuais\n")

# ---------------------------------------------------------------------
# 6. Avaliação consolidada e totais anuais (Tabela 7)
# ---------------------------------------------------------------------
cat("\n== Totais anuais ==\n")
anual_t   <- function(sci, D) sci * D * H / 1e6       # t CO2e
anual_usd <- function(custo, D) custo * D * H / 1e6   # US$
s_llm <- sci_g(E_LLM_CLASS); s_esp <- sci_g(E_ESP_CLASS)
confere(1 - s_esp / s_llm, 0.93, 2, "Redução de carbono por requisição (classificação)")
confere(c(anual_t(s_llm, 1e6), anual_t(s_esp, 1e6)), c(3.80, 0.26), 2, "Carbono anual financeiro (t)")
confere(c(anual_usd(192.48, 1e6), anual_usd(5.19, 1e6)), c(70255, 1894), 0, "Custo anual financeiro (US$)")
confere(c(anual_t(s_llm, 1e5), anual_t(s_esp, 1e5)), c(0.380, 0.026), 3, "Carbono anual administrativo (t)")
confere(c(anual_usd(276.00, 1e5), anual_usd(5.73, 1e5)), c(10074, 209), 0, "Custo anual administrativo (US$)")
confere(anual_t(s_llm - s_esp, 1e6), 3.5, 1, "Diferença anual financeira (t)")
confere(c(l30$sci[1], l30$sci[3], l70$sci[4]), c(0.0446, 0.0223, 0.0067), 4, "Carbono por requisição logístico (g)")
confere(c(anual_t(l30$sci[1], 1e4), anual_t(l30$sci[3], 1e4), anual_t(l70$sci[4], 1e4)),
        c(0.163, 0.081, 0.024), 3, "Carbono anual logístico (t)")
confere(c(1 - l30$sci[3] / l30$sci[1], 1 - l70$sci[4] / l70$sci[1]), c(0.50, 0.85), 2,
        "Redução logística (r = 30% e 70%)")
confere(anual_t(l70$sci[3] - l70$sci[4], 1e4), 0.057, 3, "Custo de carbono de exigir execução imediata (t)")
confere(c(anual_usd(CUSTO_GPT_LOG, 1e4), anual_usd(CUSTO_GPT_LOG / RAZAO_CUSTO, 1e4)), c(894, 24), 0,
        "Custo anual logístico (US$)")

cat("\nVERIFICAÇÃO CONCLUÍDA: todos os valores conferem com o artigo.\n")

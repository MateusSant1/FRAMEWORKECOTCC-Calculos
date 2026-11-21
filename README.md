# Verificação dos cenários — Framework de Decisão Ecológica para IA Corporativa

Script de verificação determinística dos cálculos do Trabalho de Conclusão de Curso **"Desenvolvimento de Framework de Tomada de Decisão Ecológica para IA Corporativa"**, de Mateus Henrique de Araújo Santos, sob orientação de Layse Santos Souza (Sistemas de Informação, Universidade Tiradentes, 2026).

O script recalcula, a partir dos dados publicados nas fontes, todos os valores numéricos dos cenários simulados do artigo e confere cada um com o valor impresso no texto. Qualquer divergência interrompe a execução com a indicação do teste que falhou.

> **Versão do artigo:** este repositório corresponde à versão `[v1.0-banca]` do artigo. A numeração de tabelas citada no script (Tabelas 4 a 7) refere-se a essa versão.

## O que o framework faz

O framework escolhe, entre alternativas de execução de uma carga de IA, a que emite menos carbono **desde que** cumpra o acordo de nível de serviço (SLA) e a qualidade mínima. O princípio é *green when possible, if possible*. A decisão segue cinco passos:

1. **Gerar alternativas:** a baseline é o LLM via API. O filtro G0 acrescenta modelos específicos de tarefa; o filtro G2 acrescenta a execução deslocada para horários de rede mais limpa.
2. **Eliminar:** G1 descarta quem excede o SLA (latência p95); G3 descarta quem fica abaixo de 90% da melhor qualidade.
3. **Pontuar:** Índice de Decisão Ecológica, `IDE = (λ·S^E + S^L + S^C) / (λ + 2)`, com λ = 1,5. Cada nota é o melhor valor dividido pelo valor da alternativa.
4. **Testar a sensibilidade:** λ ∈ {1; 1,5; 2} e ponto de inversão `λ* = (P_Y − P_X) / (S^E_X − S^E_Y)`.
5. **Validar:** C1 (conformidade), C2 (captura do ganho verde) e C3 (robustez ao peso).

O carbono por requisição é a SCI operacional: `SCI = E · PUE · I`, sem o carbono incorporado ao hardware.

## O que o script verifica

| Bloco | Conteúdo |
| --- | --- |
| Energia por requisição | Conversão das emissões medidas por Luccioni et al. em Wh por requisição e SCI operacional |
| Cenário financeiro | SST-2, SLA de 1 s, 10⁶ requisições/dia: filtros, notas, IDE com λ = 1; 1,5; 2, ponto de inversão e escolha com a maior estimativa de energia |
| Cenário administrativo | AG News, SLA de 3 s, 10⁵ requisições/dia: os mesmos itens do financeiro |
| Cenário logístico | Sumarização (CNN/DailyMail), SLA de 8 h, 10⁴ requisições/dia: execução imediata e deslocada, regra λ* = 1/r e faixa de r em que C3 falha |
| Sensibilidade | Qualidade mínima, SLA, PUE e intensidade da rede |
| Totais anuais | Carbono e custo acumulados em um ano e custo de carbono de exigir execução imediata |

## O que o script não verifica

- **A fidelidade dos dados de entrada às fontes.** Os valores das fontes estão digitados no script; o script confere as contas feitas com eles, e não se foram copiados corretamente. Para essa conferência, use a tabela de rastreabilidade abaixo e os documentos originais.
- **As citações descritivas** da Introdução e do Referencial Teórico, que são dados da literatura e não resultados de cálculo.

## Como executar

Requisitos: R 4.x, apenas com o R base (nenhum pacote adicional).

```bash
Rscript verificacao_cenarios.R
```

Alternativas sem instalação local: abrir o arquivo no RStudio ou no [Posit Cloud](https://posit.cloud) e clicar em **Source**.

Se todos os valores conferirem, a última linha impressa é:

```
VERIFICAÇÃO CONCLUÍDA: todos os valores conferem com o artigo.
```

Em caso de divergência, a execução para com a mensagem `DIVERGÊNCIA em <teste>: calculado <x>, artigo <y>` e termina com código de saída diferente de zero, o que permite usar o script em integração contínua.

## Rastreabilidade dos dados de entrada

| Constante no script | Valor | Origem |
| --- | --- | --- |
| `sst2` (F1, p50, p95, custo) | 7 alternativas | Valdes Gonzalez (2026), Tabela 3 |
| `agnews` (F1, p50, p95, custo) | 7 alternativas | Valdes Gonzalez (2026), Tabela 4 |
| Preços do GPT-4o | US$ 2,50 (entrada) e US$ 10,00 (saída) por milhão de tokens | Valdes Gonzalez (2026), Tabelas 3 e 4 |
| `I_LUCCIONI` | 297,6 gCO₂e/kWh | Luccioni, Jernite e Strubell (2024), p. 88 |
| Emissão do LLM em classificação | 4,67 g por 1.000 consultas (BLOOMz-7B) | Luccioni, Jernite e Strubell (2024), p. 94 |
| Emissão do modelo específico em classificação | 0,32 g por 1.000 consultas (BERT de sentimento) | Luccioni, Jernite e Strubell (2024), p. 94 |
| Emissão em sumarização | 20 g (propósito geral) e 10 g (específico) por 1.000 inferências; outra ponta: 30 g e 4 g | Luccioni, Jernite e Strubell (2024), p. 90 |
| Tokens da sumarização | 54 de entrada; 11 de saída (média dos modelos zero-shot no CNN/DailyMail) | Luccioni, Jernite e Strubell (2024), Tabela 4, p. 92 |
| `E_LLM_MAX` | 0,42 Wh por consulta curta do GPT-4o | Jegham et al. (2025), p. 10 |
| `PUE` | 1,58 (média da indústria) | Safari et al. (2025), Seção 4 |
| `I_REDE` | 420 gCO₂e/kWh (média regional) | Nadeem et al. (2026), Seção 3.10, p. 11 |
| Faixa de `r` | 30% a 70% de redução | Piastou (2026), resumo |
| `RAZAO_LAT` | 3,80 = 410,81 ÷ 108,19 (GPT-4o ZS ÷ DistilBERT, p50) | Valdes Gonzalez (2026), Tabela 4 |
| `RAZAO_CUSTO` | 37,1 ≈ 192,48 ÷ 5,19 (GPT-4o ZS ÷ DistilBERT), arredondada como no texto | Valdes Gonzalez (2026), Tabela 3 |

### Premissas do autor

| Constante | Valor |
| --- | --- |
| SLA (p95) | 1 s (financeiro), 3 s (administrativo), 8 h (logístico) |
| Volume D | 10⁶, 10⁵ e 10⁴ requisições por dia |
| Horizonte H | 365 dias |
| Qualidade mínima | 90% da melhor qualidade do cenário |
| `ESPERA_MS` | 4 h de espera da execução deslocada (metade da janela de 8 h) |
| Carbono incorporado (M) | 0 (SCI operacional) |
| Energia do few-shot | Igual à do zero-shot |
| Qualidade do GPT-4o em sumarização | Aprovada por premissa (não medida nas fontes) |
| Latência e custo do sumarizador específico | Extrapolados das razões medidas em classificação |

PUE e intensidade da rede valem igualmente para todas as alternativas de um cenário. Por isso alteram os totais anuais, mas não a escolha; o bloco de sensibilidade confirma isso.

## Referências das fontes

- JEGHAM, N. et al. How hungry is AI? Benchmarking energy, water, and carbon footprint of LLM inference. arXiv:2505.09598v6, 2025.
- LUCCIONI, A. S.; JERNITE, Y.; STRUBELL, E. Power Hungry Processing: Watts Driving the Cost of AI Deployment? In: ACM FAccT, 2024, p. 85–99. DOI: 10.1145/3630106.3658542.
- NADEEM, M. et al. Sustainable AI framework for carbon footprint assessment and green AI lifecycle management. AI and Ethics, v. 6, n. 389, 2026.
- PIASTOU, M. Green software development using carbon aware scheduling. Latin-American Journal of Computing, v. 13, n. 1, 2026.
- SAFARI, A. et al. A Systematic Review of Energy Efficiency Metrics for Optimizing Cloud Data Center Operations and Management. Electronics, v. 14, n. 11, 2214, 2025. DOI: 10.3390/electronics14112214.
- VALDES GONZALEZ, A. A. Cost-Aware Model Selection for Text Classification: Multi-Objective Trade-offs Between Fine-Tuned Encoders and LLM Prompting in Production. arXiv:2602.06370v1, 2026.

Os artigos não são distribuídos neste repositório; consulte-os pelas referências acima.

## Como citar

> SANTOS, M. H. A.; SOUZA, L. S. Desenvolvimento de Framework de Tomada de Decisão Ecológica para IA Corporativa. Trabalho de Conclusão de Curso (Sistemas de Informação) — Universidade Tiradentes, Aracaju, 2026.

## Licença

O código está sob a licença `[MIT]`. Os valores numéricos de entrada pertencem às fontes citadas e são reproduzidos apenas para fins de verificação acadêmica.

<div align="center">

<img src="assets/banner.png" width="760" alt="tern-omp-usage: limites do Claude e do Codex pelo omp, direto na barra de status do Tern">

[![check](https://github.com/joaodutra88/tern-omp-usage/actions/workflows/check.yml/badge.svg)](https://github.com/joaodutra88/tern-omp-usage/actions/workflows/check.yml)
[![License: MIT](https://img.shields.io/badge/license-MIT-green.svg)](LICENSE)
[![GitHub stars](https://img.shields.io/github/stars/joaodutra88/tern-omp-usage?style=flat)](https://github.com/joaodutra88/tern-omp-usage/stargazers)
[![Latest release](https://img.shields.io/github/v/release/joaodutra88/tern-omp-usage)](https://github.com/joaodutra88/tern-omp-usage/releases/latest)

Um plugin de barra de status do [Tern](https://stencil.so/tern) para usuários do [omp](https://omp.sh). Ele mantém na tela, em uma única linha, os limites de assinatura do Claude e do Codex, o orçamento de gastos da semana e os tokens e o custo de hoje. Clique no custo de hoje para abrir um painel com os últimos 7 dias.

**[Instalação](#instalação)** · **[O que cada parte significa](#o-que-cada-parte-significa)** · **[Configuração](#configuração)** · **[FAQ](#faq)** · **[Contribuindo](#contribuindo)**

[English](README.md) | **Português** | [Español](README.es.md) | [简体中文](README.zh-CN.md) | [日本語](README.ja.md)

O README em inglês é a referência e prevalece se houver diferença.

<img src="assets/statusline.png" alt="Uso do Claude e do Codex na barra de status do Tern">

</div>

## O que ele responde

Tudo fica na barra de status, então as respostas estão na tela enquanto você trabalha:

- **Dá pra encarar uma execução pesada hoje?** Um orçamento da semana de trabalho: cada dia útil libera 20% da cota semanal, e a parte de um feriado fica guardada.
- **Quanto custou hoje?** Tokens e custo ao preço da API desde a meia-noite, em todos os provedores que o omp acompanha. O painel mostra também os últimos 7 dias e o mês.
- **Tenho um reset guardado?** Resets salvos de limite de uso para Claude e Codex.
- **Quando o limite acaba?** No ritmo atual, quanto tempo falta para a janela de 5h ou a semanal travar, quando isso acontece antes do reset. Um aviso aparece quando uma janela chega a 80%, trava ou volta a liberar.
- **Claude e Codex lado a lado**, ambos lidos pelo omp, sem nenhum login novo.

## O que cada parte significa

| Aparência | Significado |
|---|---|
| <img src="assets/seg-window.png" height="28" alt="janela de 5h"> | Uso de uma janela: 5h, semana (`wk`) e Fable, quando o seu plano tem. Cada ponto mantém sua própria cor, do verde ao vermelho, e a porcentagem assume a cor do último ponto alcançado. Em 80% (dá para mudar), a porcentagem vira um selo vermelho pulsante. |
| <img src="assets/seg-reset.png" height="28" alt="contagem até o reset"> | Tempo até a janela de 5h do Claude ser redefinida. Fica verde quando faltam menos de 30 min e a janela de 5h está em 80% ou mais, o que significa que o alívio está perto. |
| `⏳23m` | Logo depois da barra de 5h ou `wk` do Claude: na média de uso desde que a janela abriu, ela acaba nesse tempo, antes do reset. Aparece a partir de 50% de uso. Os alertas chegam como avisos: uma janela que atinge o limite do selo vermelho, trava ou volta a liberar. |
| <img src="assets/seg-credits.png" height="28" alt="resets salvos"> | Resets de limite de uso que você tem guardados. |
| <img src="assets/seg-budget.png" height="28" alt="orçamento da semana de trabalho"> | Orçamento da semana de trabalho. Cada dia útil (de segunda a sexta, a menos que você mude) da janela atual de 7 dias libera uma parte igual da cota semanal, 20% com cinco dias. `left` é a cota liberada e ainda não gasta. `over` (vermelho pulsante) significa que você está gastando à frente da semana. |
| <img src="assets/seg-codex.png" height="28" alt="Codex"> | Codex. `×2` é o número de contas vinculadas, e as janelas mostram a parte das contas que já foi esgotada. |
| <img src="assets/seg-today.png" height="28" alt="tokens e custo de hoje"> | Tokens e custo ao preço da API desde a meia-noite local, todos os provedores, a partir de `omp stats`. Leituras de cache contam como tokens, então a maior parte desse número é cache. Clique para abrir o painel. |
| <img src="assets/seg-refresh.png" height="28" alt="atualizar"> | Atualizar agora. Clicar em qualquer outro segmento de uso faz o mesmo. |

### Painel

**OMP usage: dashboard** (ou um clique nos tokens ou no custo de hoje) abre um painel ao lado do que você está usando. Ele mostra o uso de 5h e semanal do Claude e do Codex, hora a hora, nos últimos 7 dias, a partir de `omp usage --history`, e o custo ao preço da API de hoje, dos últimos 7 dias e do mês, com uma barra por dia. Aperte `r` para ler o histórico de novo.

O `omp stats` só guarda cerca de um dia, então o plugin registra o total de cada dia por conta própria. A semana e o mês vão se completando a partir do dia em que você instala a 0.4.0.

## Como fica ao longo da semana

Estes exemplos foram renderizados a partir de respostas fixas do `omp`, então você pode ver estados que não acontecem todos os dias.

**Manhã tranquila.** Tudo verde, bastante orçamento.

<p align="center"><img src="assets/state-calm.png" alt="tranquilo"></p>

**Uso subindo.** Um `↑` aparece quando uma janela subiu 3 pontos ou mais desde a última leitura, 5 minutos antes.

<p align="center"><img src="assets/state-rising.png" alt="subindo"></p>

**Janela de 5h quente.** Em 86%, a porcentagem vira um selo vermelho, e o reset fica verde porque o alívio está a 21 minutos.

<p align="center"><img src="assets/state-hot.png" alt="quente"></p>

**À frente da semana.** 65% da semana usados com apenas 40% liberados: `over 25%` pulsa até o próximo dia útil alcançar.

<p align="center"><img src="assets/state-over.png" alt="acima do orçamento"></p>

**Bloqueado.** Uma janela em 100% mostra um selo pulsante com o tempo até ser liberada e os seus resets salvos.

<p align="center"><img src="assets/state-locked.gif" alt="bloqueado"></p>

## Instalação

```sh
tern plugin install https://github.com/joaodutra88/tern-omp-usage
```

Você precisa do `omp` logado na Anthropic e/ou no OpenAI Codex, de forma que `omp usage` funcione em um terminal. O plugin usa o omp que o Tern gerencia (`%LOCALAPPDATA%\Tern\omp\bin\omp.exe` no Windows, `~/Library/Application Support/Tern/omp/bin/omp` no macOS) e recorre ao `omp` no `PATH`. Se o daemon do Tern não encontrar o executável, defina `OMP_USAGE_BIN` com o caminho completo.

### Atualizações

Uma vez por dia o plugin consulta o GitHub atrás de uma versão nova. Quando existe, um `⬆ 0.5.0` azul aparece no início dos segmentos dele e um aviso mostra isso uma vez. Clique nele, ou rode **OMP usage: update to the latest version**, e o plugin se reinstala a partir deste repositório (`tern plugin install … --force`). Suas configurações e o seu `extras.luau` continuam. Depois da atualização, um aviso mostra a nova versão, e **OMP usage: what's new** abre as notas da versão.

Um checkout vinculado (`tern plugin link`) se atualiza com `git pull`. Para parar a consulta, oculte a parte `updates` (veja [Configuração](#configuração)) ou defina `OMP_USAGE_NO_UPDATE_CHECK=1`.

**Está na 0.3.x?** Essas versões não verificam atualizações. Rode o comando de instalação acima uma vez com `--force`, e da 0.4.0 em diante o próprio plugin avisa você.

Para saber das versões novas também por e-mail, use **Watch → Custom → Releases** no topo deste repositório.

### Instalar com o seu agente de IA

Cole isto no omp, no Claude Code, no Codex ou em qualquer agente que consiga executar comandos:

```text
Install the Tern plugin https://github.com/joaodutra88/tern-omp-usage for me.
1. Check `omp usage --json -p anthropic` (or `-p openai-codex`) works. If it doesn't, help me sign in with omp first.
2. Run `tern plugin install https://github.com/joaodutra88/tern-omp-usage`.
3. Run `tern plugin list --json` and confirm `omp-usage` has status "ready".
4. If it isn't ready, read the lines containing `omp-usage` in Tern's log
   (`%LOCALAPPDATA%\Tern\Logs\tern.log` on Windows) and the repo's AGENTS.md, then tell me what is wrong.
5. Explain what each part of the status line means, using the README.
```

## O que ele executa e o que toca

O plugin não lê credenciais. Ele executa o omp e faz uma única requisição de rede própria:

| Comando | Quando |
|---|---|
| `omp usage --json -p anthropic` | A cada 5 min. O endpoint de uso da Anthropic responde 429 abaixo de cerca de 5 min. |
| `omp usage --json -p openai-codex` | A cada 5 min |
| `omp stats --json` | A cada 5 min |
| `omp usage --history --json --days 7` | Quando o painel abre e quando você aperta `r` nele |
| `omp usage invalidate` | Quando você clica em um segmento, para pular o cache do omp |
| `GET api.github.com/repos/joaodutra88/tern-omp-usage/releases/latest` | Uma vez por dia por máquina, sem token; desligue com a parte `updates` ou com `OMP_USAGE_NO_UPDATE_CHECK=1` |
| `tern plugin install https://github.com/joaodutra88/tern-omp-usage --force` | Só quando você clica em `⬆` ou roda o comando de atualização |

As configurações, os tokens e o custo de cada dia (para o painel), a última versão vista e uma cópia do seu `extras.luau` (feita antes de uma atualização) vão para a pasta de dados do plugin (`tern.kv`), e para nenhum outro lugar. O formatador da barra só lê os valores em cache dessas chamadas, porque o Tern dá 4 ms para um formatador.

## Configuração

Abra a paleta de comandos e digite `OMP usage`. As configurações ficam na pasta de dados do plugin, então uma atualização ou reinstalação as mantém.

| Comando | O que faz |
|---|---|
| **OMP usage: show or hide a part…** | Digite uma parte para ligar ou desligar: `claude`, `codex`, `today`, `cost`, `budget`, `reset`, `credits`, `fable`, `forecast` (o `⏳`), `alerts` (os avisos), `updates`. |
| **OMP usage: language…** | `en`, `pt-BR`, `es`, `zh-CN`, `ja`, `de` ou `fr`. |
| **OMP usage: work days per week…** | Quantos dias, contando a partir de segunda, liberam a cota semanal. O padrão `5` significa de segunda a sexta, 20% cada. |
| **OMP usage: red badge threshold…** | A porcentagem em que uma janela vira o selo vermelho pulsante (padrão 80). |
| **OMP usage: reset settings** | Volta aos padrões. |
| **OMP usage: check for updates** | Consulta o GitHub na hora, mesmo com `updates` oculto. |
| **OMP usage: dashboard** | Abre o painel, ou foca nele quando esta janela já tem um. |
| **OMP usage: what's new** | Abre as notas da versão que você está rodando. |

Se o daemon do Tern não encontrar o `omp`, defina a variável de ambiente `OMP_USAGE_BIN` com o caminho completo. As cores são CSS simples no final de `window.luau`. Cada segmento é `#statusline .sl-plugin[title="plugin.omp-usage.<name>"]`.

### No seu idioma

Cada palavra que o plugin mostra fica em `labels.luau`, uma tabela por idioma. Para adicionar um, copie `en`, traduza os valores e abra um pull request. As chaves que um idioma deixar de fora caem no inglês.

### Seus próprios segmentos

Se existir um arquivo `extras.luau` ao lado de `window.luau`, o plugin o carrega. O Git o ignora, então segmentos pessoais nunca chegam ao repositório. Uma atualização copia o arquivo antes para a pasta de dados do plugin, e o plugin carrega essa cópia quando o arquivo ao lado de `window.luau` não existe mais:

```luau
local M = {}
function M.init(hidden, every) end -- register commands, timers, CSS
function M.segments(out, pane) end -- insert segments before the usage ones
return M
```

## FAQ

**`tern plugin list` mostra o plugin como `disabled`.**
O Tern desativa um plugin que dá erro ou cujo formatador da barra estoura o tempo previsto. Rode `tern plugin reload`, depois procure as linhas com `omp-usage` no log do Tern (`%LOCALAPPDATA%\Tern\Logs\tern.log` no Windows) e abra uma issue com elas.

**A barra mostra `✻ Claude ?` ou `⬢ Codex ?`.**
A última chamada de `omp usage` falhou. Confira se `omp usage --json -p anthropic` (ou `-p openai-codex`) funciona em um terminal e, se não funcionar, faça login no omp. Clique em qualquer segmento para tentar de novo.

**Não aparece nada.**
Confirme que a barra de status está ligada (`"status_bar": true` nas configurações do Tern). Se estiver, o daemon do Tern pode não encontrar o `omp`: defina `OMP_USAGE_BIN` com o caminho completo e reinicie o Tern.

**Os números ficam atrás do claude.ai.**
Eles vêm do mesmo endpoint de uso, pelo omp, a cada 5 minutos, porque a Anthropic limita a frequência de consultas. Clique em um segmento para forçar uma leitura nova.

**Por que a contagem de tokens de hoje é tão alta?**
Ela inclui as leituras de cache, que formam a maior parte da entrada de um agente. O custo é o que esses tokens custariam ao preço da API, não o que a sua assinatura cobra.

**Como atualizo?**
Clique no `⬆` azul quando ele aparecer, ou rode **OMP usage: update to the latest version**. Na mão: `tern plugin install https://github.com/joaodutra88/tern-omp-usage --force`. Versões anteriores à 0.4.0 não verificam atualizações, e no Windows a atualização da 0.4.0 falha com "The process cannot access the file", então atualize essas uma vez na mão.

**Como desinstalo?**
`tern plugin remove omp-usage`.

## Contribuindo

Este projeto é open source sob MIT: use, faça fork, altere, publique. Issues e pull requests são abertos a todos.

- `python scripts/check.py` roda a checagem de sintaxe, os testes unitários e as checagens de CSS e do manifesto; `--integration` roda o plugin inteiro num Tern falso, com respostas gravadas do `omp` e do GitHub. O CI roda as duas em todo pull request, no Linux, no Windows e no macOS. Adicione `--tern` para também recarregar o plugin no seu Tern e ler o log dele.
- Usando um agente de IA? Aponte para [AGENTS.md](AGENTS.md). Ele explica as regras que são fáceis de quebrar e como abrir um relatório de bug limpo para você.
- O que está planejado, e o que uma mudança precisa respeitar: [ROADMAP.md](ROADMAP.md) (em inglês). Ideias vão para as [Discussions](https://github.com/joaodutra88/tern-omp-usage/discussions); as issues marcadas como **good first issue** são um bom começo.
- Mais em [CONTRIBUTING.md](CONTRIBUTING.md). Todos que participam seguem o [Código de Conduta](CODE_OF_CONDUCT.md); problemas de segurança passam pelo [SECURITY.md](SECURITY.md).

## Histórico de estrelas

[![Gráfico de histórico de estrelas](https://api.star-history.com/svg?repos=joaodutra88/tern-omp-usage&type=Date)](https://star-history.com/#joaodutra88/tern-omp-usage&Date)

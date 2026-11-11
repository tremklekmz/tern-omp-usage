<div align="center">

<img src="assets/banner.png" width="760" alt="tern-omp-usage: límites de Claude y Codex desde omp, directamente en la barra de estado de Tern">

[![check](https://github.com/joaodutra88/tern-omp-usage/actions/workflows/check.yml/badge.svg)](https://github.com/joaodutra88/tern-omp-usage/actions/workflows/check.yml)
[![License: MIT](https://img.shields.io/badge/license-MIT-green.svg)](LICENSE)
[![GitHub stars](https://img.shields.io/github/stars/joaodutra88/tern-omp-usage?style=flat)](https://github.com/joaodutra88/tern-omp-usage/stargazers)
[![Latest release](https://img.shields.io/github/v/release/joaodutra88/tern-omp-usage)](https://github.com/joaodutra88/tern-omp-usage/releases/latest)

Un plugin de barra de estado de [Tern](https://stencil.so/tern) para usuarios de [omp](https://omp.sh). Mantiene en pantalla los límites de suscripción de Claude y Codex, el presupuesto de gasto de esta semana y los tokens y el costo de hoy, en una sola línea. Haz clic en el costo de hoy para abrir un dashboard de los últimos 7 días.

**[Instalación](#instalación)** · **[Qué significa cada parte](#qué-significa-cada-parte)** · **[Configuración](#configuración)** · **[FAQ](#faq)** · **[Contribuir](#contribuir)**

[English](README.md) | [Português](README.pt-BR.md) | **Español** | [简体中文](README.zh-CN.md) | [日本語](README.ja.md)

El README en inglés es la referencia y prevalece si hay diferencias.

<img src="assets/statusline.png" alt="Uso de Claude y Codex en la barra de estado de Tern">

</div>

## Qué responde

Todo queda en la barra de estado, así que las respuestas están en pantalla mientras trabajas:

- **¿Puedo permitirme una ejecución pesada hoy?** Un presupuesto de la semana laboral: cada día hábil desbloquea el 20% de la cuota semanal, y la parte de un feriado se traslada.
- **¿Cuánto costó hoy?** Tokens y costo a precio de API desde medianoche, de todos los proveedores que omp registra. El dashboard añade los últimos 7 días y este mes.
- **¿Tengo un reinicio guardado?** Reinicios guardados de límites de uso para Claude y Codex.
- **¿Cuándo me quedo sin cuota?** Al ritmo actual, cuánto falta para que se bloquee la ventana de 5h o la semanal, cuando eso ocurre antes de su reinicio. Un aviso emergente cuando una ventana llega al 80%, se bloquea o vuelve a liberarse.
- **Claude y Codex lado a lado**, ambos leídos a través de omp, sin nada nuevo que iniciar sesión.

## Qué significa cada parte

| Se ve así | Significado |
|---|---|
| <img src="assets/seg-window.png" height="28" alt="ventana de 5h"> | Uso de una ventana: 5h, semana (`wk`) y Fable cuando tu plan lo incluye. Cada punto conserva su propio color, de verde a rojo, y el porcentaje toma el color del último punto alcanzado. Al 80% (puedes cambiarlo) el porcentaje se convierte en una insignia roja pulsante. |
| <img src="assets/seg-reset.png" height="28" alt="cuenta regresiva del reinicio"> | Tiempo hasta que se reinicia la ventana de 5h de Claude. Se pone verde cuando faltan menos de 30 min y la ventana de 5h está al 80% o más, lo que indica que el alivio está cerca. |
| `⏳23m` | Justo después de la barra de 5h o `wk` de Claude: al ritmo promedio desde que se abrió esa ventana, se agota en este tiempo, antes de su reinicio. Aparece a partir del 50% de uso. Las alertas llegan como avisos emergentes: una ventana que alcanza el umbral de la insignia roja, se bloquea o vuelve a liberarse. |
| <img src="assets/seg-credits.png" height="28" alt="reinicios guardados"> | Reinicios de límite de uso que tienes guardados. |
| <img src="assets/seg-budget.png" height="28" alt="presupuesto de la semana laboral"> | Presupuesto de la semana laboral. Cada día hábil (de lunes a viernes, salvo que lo cambies) de la ventana actual de 7 días desbloquea una parte igual de la cuota semanal, el 20% con cinco días. `left` es la cuota desbloqueada y aún no gastada. `over` (rojo pulsante) significa que estás gastando por delante de la semana. |
| <img src="assets/seg-codex.png" height="28" alt="Codex"> | Codex. `×2` es el número de cuentas vinculadas, y las ventanas muestran la proporción de cuentas agotadas. |
| <img src="assets/seg-today.png" height="28" alt="tokens y costo de hoy"> | Tokens y costo a precio de API desde la medianoche local, todos los proveedores, desde `omp stats`. Las lecturas de caché cuentan como tokens, así que la mayor parte de este número es caché. Haz clic para abrir el dashboard. |
| <img src="assets/seg-refresh.png" height="28" alt="actualizar"> | Actualizar ahora. Hacer clic en cualquier otro segmento de uso hace lo mismo. |

### Dashboard

**OMP usage: dashboard** (o un clic en los tokens o el costo de hoy) abre un panel junto al que estás usando. Muestra el uso de 5h y semanal de Claude y Codex hora por hora durante los últimos 7 días, desde `omp usage --history`, y el costo a precio de API de hoy, de los últimos 7 días y de este mes, con una barra por día. Presiona `r` para volver a leer el historial.

`omp stats` solo guarda alrededor de un día, así que el plugin conserva por su cuenta el total de cada día. La semana y el mes se van llenando a partir del día en que instalas la 0.4.0.

## Cómo se ve a lo largo de la semana

Estas imágenes se generaron a partir de respuestas fijas de `omp`, así que puedes ver estados que no ocurren todos los días.

**Mañana tranquila.** Todo en verde, mucho presupuesto.

<p align="center"><img src="assets/state-calm.png" alt="tranquila"></p>

**El uso sube.** Aparece una `↑` cuando una ventana subió 3 puntos o más desde la última lectura, 5 minutos antes.

<p align="center"><img src="assets/state-rising.png" alt="subiendo"></p>

**Ventana de 5h caliente.** Al 86% el porcentaje se convierte en una insignia roja, y el reinicio se pone verde porque el alivio está a 21 minutos.

<p align="center"><img src="assets/state-hot.png" alt="caliente"></p>

**Por delante de la semana.** Se ha usado el 65% de la semana con solo el 40% desbloqueado: `over 25%` pulsa hasta que el siguiente día hábil se ponga al día.

<p align="center"><img src="assets/state-over.png" alt="sobre presupuesto"></p>

**Bloqueada.** Una ventana al 100% muestra una insignia pulsante con el tiempo hasta que se libere y tus reinicios guardados.

<p align="center"><img src="assets/state-locked.gif" alt="bloqueada"></p>

## Instalación

```sh
tern plugin install https://github.com/joaodutra88/tern-omp-usage
```

Necesitas `omp` con sesión iniciada en Anthropic y/o OpenAI Codex, para que `omp usage` funcione en una terminal. El plugin usa el omp que gestiona Tern (`%LOCALAPPDATA%\Tern\omp\bin\omp.exe` en Windows, `~/Library/Application Support/Tern/omp/bin/omp` en macOS) y recurre a `omp` en el `PATH`. Si el demonio de Tern no lo encuentra, define `OMP_USAGE_BIN` con la ruta completa.

### Actualizaciones

Una vez al día el plugin revisa en GitHub si hay una versión más nueva. Cuando la hay, aparece un `⬆ 0.5.0` azul al inicio de sus segmentos y un aviso emergente te lo dice una vez. Haz clic en él, o ejecuta **OMP usage: update to the latest version**, y el plugin se reinstala desde este repositorio (`tern plugin install … --force`). Tu configuración y tu `extras.luau` se conservan. Después de la actualización, un aviso emergente indica la nueva versión, y **OMP usage: what's new** abre sus notas de la versión.

Un checkout vinculado (`tern plugin link`) se actualiza con `git pull`. Para dejar de revisar, oculta la parte `updates` (ver [Configuración](#configuración)) o define `OMP_USAGE_NO_UPDATE_CHECK=1`.

**¿Estás en la 0.3.x?** Esas versiones no revisan actualizaciones. Ejecuta una vez el comando de instalación de arriba con `--force`, y a partir de la 0.4.0 el plugin te avisa por sí mismo.

Para enterarte de las versiones también por correo electrónico, usa **Watch → Custom → Releases** en la parte superior de este repositorio.

### Instalar con tu agente de IA

Pega esto en omp, Claude Code, Codex o cualquier agente que pueda ejecutar comandos:

```text
Install the Tern plugin https://github.com/joaodutra88/tern-omp-usage for me.
1. Check `omp usage --json -p anthropic` (or `-p openai-codex`) works. If it doesn't, help me sign in with omp first.
2. Run `tern plugin install https://github.com/joaodutra88/tern-omp-usage`.
3. Run `tern plugin list --json` and confirm `omp-usage` has status "ready".
4. If it isn't ready, read the lines containing `omp-usage` in Tern's log
   (`%LOCALAPPDATA%\Tern\Logs\tern.log` on Windows) and the repo's AGENTS.md, then tell me what is wrong.
5. Explain what each part of the status line means, using the README.
```

## Qué ejecuta y qué toca

El plugin no lee credenciales. Ejecuta omp y hace una única petición de red propia:

| Comando | Cuándo |
|---|---|
| `omp usage --json -p anthropic` | Cada 5 min. El endpoint de uso de Anthropic responde 429 por debajo de unos 5 min. |
| `omp usage --json -p openai-codex` | Cada 5 min |
| `omp stats --json` | Cada 5 min |
| `omp usage --history --json --days 7` | Al abrir el dashboard y al presionar `r` en él |
| `omp usage invalidate` | Al hacer clic en un segmento, para saltarse la caché de omp |
| `GET api.github.com/repos/joaodutra88/tern-omp-usage/releases/latest` | Una vez al día por máquina, sin token; se desactiva con la parte `updates` o `OMP_USAGE_NO_UPDATE_CHECK=1` |
| `tern plugin install https://github.com/joaodutra88/tern-omp-usage --force` | Solo cuando haces clic en `⬆` o ejecutas el comando de actualización |

La configuración, los tokens y el costo de cada día (para el dashboard), la última versión vista y una copia de tu `extras.luau` (hecha antes de una actualización) se guardan en la carpeta de datos del plugin (`tern.kv`), en ningún otro lugar. El formateador de la barra solo lee los valores en caché que dejan esas llamadas, porque Tern le da a un formateador 4 ms.

## Configuración

Abre la paleta de comandos y escribe `OMP usage`. La configuración se guarda en la carpeta de datos del plugin, así que una actualización o una reinstalación la conserva.

| Comando | Qué hace |
|---|---|
| **OMP usage: show or hide a part…** | Escribe una parte para activarla o desactivarla: `claude`, `codex`, `today`, `cost`, `budget`, `reset`, `credits`, `fable`, `forecast` (el `⏳`), `alerts` (los avisos emergentes), `updates`. |
| **OMP usage: language…** | `en`, `pt-BR`, `es`, `zh-CN`, `ja`, `de` o `fr`. |
| **OMP usage: work days per week…** | Cuántos días, contados desde el lunes, desbloquean la cuota semanal. El valor por defecto `5` significa de lunes a viernes, 20% cada uno. |
| **OMP usage: red badge threshold…** | El porcentaje en el que una ventana se convierte en la insignia roja pulsante (por defecto 80). |
| **OMP usage: reset settings** | Vuelve a los valores por defecto. |
| **OMP usage: check for updates** | Consulta GitHub ahora, incluso con `updates` oculta. |
| **OMP usage: dashboard** | Abre el dashboard, o lo enfoca cuando esta ventana ya tiene uno. |
| **OMP usage: what's new** | Abre las notas de la versión que estás usando. |

Si el demonio de Tern no encuentra `omp`, define la variable de entorno `OMP_USAGE_BIN` con su ruta completa. Los colores son CSS simple al final de `window.luau`. Cada segmento es `#statusline .sl-plugin[title="plugin.omp-usage.<name>"]`.

### En tu idioma

Cada palabra que muestra el plugin vive en `labels.luau`, una tabla por idioma. Para añadir uno, copia `en`, traduce los valores y abre un pull request. Las claves que un idioma no incluya recurren al inglés.

### Tus propios segmentos

Si existe un archivo `extras.luau` junto a `window.luau`, el plugin lo carga. Git lo ignora, así que tus segmentos personales nunca llegan al repositorio. Una actualización lo copia primero a la carpeta de datos del plugin, y el plugin carga esa copia cuando ya no está la que va junto a `window.luau`:

```luau
local M = {}
function M.init(hidden, every) end -- registrar comandos, temporizadores, CSS
function M.segments(out, pane) end -- insertar segmentos antes de los de uso
return M
```

## FAQ

**`tern plugin list` muestra el plugin como `disabled`.**
Tern desactiva un plugin que produce errores o cuyo formateador de estado supera su presupuesto de tiempo. Ejecuta `tern plugin reload`, luego busca las líneas con `omp-usage` en el log de Tern (`%LOCALAPPDATA%\Tern\Logs\tern.log` en Windows) y abre un issue con ellas.

**La barra muestra `✻ Claude ?` o `⬢ Codex ?`.**
La última llamada a `omp usage` falló. Comprueba que `omp usage --json -p anthropic` (o `-p openai-codex`) funciona en una terminal, e inicia sesión con omp si no funciona. Haz clic en cualquier segmento para reintentar.

**No aparece nada.**
Asegúrate de que la barra de estado esté activada (`"status_bar": true` en la configuración de Tern). Si lo está, es posible que el demonio de Tern no encuentre `omp`: define `OMP_USAGE_BIN` con su ruta completa y reinicia Tern.

**Los números van por detrás de claude.ai.**
Vienen del mismo endpoint de uso a través de omp, cada 5 minutos, porque Anthropic limita la frecuencia de las consultas más rápidas. Haz clic en un segmento para forzar una lectura nueva.

**¿Por qué el conteo de tokens de hoy es tan alto?**
Incluye las lecturas de caché, que son la mayor parte de la entrada de un agente. El costo es lo que esos tokens costarían a precio de API, no lo que cobra tu suscripción.

**¿Cómo lo actualizo?**
Haz clic en el `⬆` azul cuando aparezca, o ejecuta **OMP usage: update to the latest version**. A mano: `tern plugin install https://github.com/joaodutra88/tern-omp-usage --force`. Las versiones anteriores a la 0.4.0 no revisan actualizaciones, y en Windows la actualización de la 0.4.0 falla con "The process cannot access the file", así que actualízalas una vez a mano.

**¿Cómo lo desinstalo?**
`tern plugin remove omp-usage`.

## Contribuir

Es código abierto bajo MIT: úsalo, haz un fork, cámbialo, publícalo. Los issues y los pull requests están abiertos para todos.

- `python scripts/check.py` ejecuta la revisión de sintaxis, las pruebas unitarias y las revisiones de CSS y del manifiesto; `--integration` ejecuta el plugin completo en un Tern simulado, con respuestas grabadas de `omp` y de GitHub. CI ejecuta ambas en cada pull request, en Linux, Windows y macOS. Añade `--tern` para además recargar el plugin en tu Tern y leer su log.
- ¿Usas un agente de IA? Apúntalo a [AGENTS.md](AGENTS.md). Explica las reglas que se rompen fácilmente y cómo presentar un reporte de bug limpio para ti.
- Lo que está planeado, y lo que un cambio tiene que respetar: [ROADMAP.md](ROADMAP.md) (en inglés). Las ideas van a [Discussions](https://github.com/joaodutra88/tern-omp-usage/discussions); los issues marcados como **good first issue** son un buen punto de partida.
- Más en [CONTRIBUTING.md](CONTRIBUTING.md). Todos los participantes siguen el [Código de conducta](CODE_OF_CONDUCT.md); los problemas de seguridad se tratan según [SECURITY.md](SECURITY.md).

## Historial de estrellas

[![Star History Chart](https://api.star-history.com/svg?repos=joaodutra88/tern-omp-usage&type=Date)](https://star-history.com/#joaodutra88/tern-omp-usage&Date)

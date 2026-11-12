# Notes for AI coding agents

You are helping someone use, change or report a problem with **tern-omp-usage**, a [Tern](https://stencil.so/tern) window plugin that offers Claude and Codex limits from `omp` as widgets in Tern's widget bar. Read this file before touching the code.

## Map

| File | What lives there |
|---|---|
| `plugin.toml` | Manifest. `id = "omp-usage"`; every command is prefixed `plugin.omp-usage.` and every widget is placed as `omp-usage/<id>`; one block, `dashboard`. |
| `window.luau` | Entry point: timers, the refresh and dashboard commands, the widgets' registration (again after a language change), the optional `extras.luau` hook. |
| `host.luau` | Host half: the `dashboard` block (runs `omp usage --history`, draws the cards, `r` refreshes). |
| `history.luau` | The dashboard's data, with no `tern` calls: hourly series per limit and the cost of today, 7 days and the month. |
| `usage.luau` | Everything about usage: runs `omp`, parses its JSON, the widgets (`M.widgets`), the limits' colored dots (`M.paint`: one CSS gradient clipped to each limit's text, rebuilt after a fetch and on the minute tick, so keep one cell per character there), the `⏳` forecast and the toasts (threshold, lock and free; a saved reset usable or expiring; a login omp turned off). |
| `config.luau` | Finds `omp` (`OMP_USAGE_BIN`, then the copy Tern manages, then `PATH`); settings in `tern.kv` (the `alerts` and `updates` parts, language, work days, red-badge threshold) and the palette commands that change them. |
| `labels.luau` | Every word the plugin shows, one table per language. |
| `update.luau` | Daily GitHub release check, the `⬆` widget and its toast, the one-click reinstall, the toast after an update. |
| `tests/*_test.luau` | Unit: one module against a fake `tern` (canned `omp` replies, a canned GitHub answer); checks what each widget and toast says. |
| `tests/integration/` | Integration: `harness.luau` loads both halves like Tern, with a fake clock, Tern's budgets, a Windows-like reinstall and the recorded replies in `fixtures.luau`; scenarios in `plugin_test.luau`. |
| `scripts/check.py` | The gate: plain (unit), `--integration`, `--tern`. CI runs the first two on every pull request. |

## Rules that are easy to break

- **A widget's render has 4 ms.** Tern disables a plugin that goes over. Never run a process, read a file or walk directories inside a widget's `render` (or `tern.chrome.status`); do it in `tern.timer` or a `tern.process.run` callback, cache the result and call `tern.chrome.refresh()`.
- **Widget ids are in people's saved bars** (`omp-usage/<id>` in Tern's settings). Renaming or removing one takes it off every bar that placed it; add a new id instead, and say so in the changelog.
- **Timers and callbacks have 50 ms.** Over that, Tern turns off every timer of the plugin until a reload, and the bar freezes. Start one process or request per callback at most; start the next one from its callback, or from another timer. The integration harness fails a change that breaks this.
- **Run installs outside the plugin folder.** `tern.process.run` starts in the plugin's folder by default, and on Windows `tern plugin install --force` can't replace a folder a process is running in: pass `cwd = tern.plugin.data`.
- **Tern's CSS is a subset.** `text-shadow`, `margin-block` and friends are rejected (the check catches them). The widgets need no CSS: a view's `tone` (`ok`, `warn`, `error`, `accent`, `muted`) colors it in any theme.
- **UTF-8.** Strings sent to Tern must stay valid UTF-8. Cut text by characters (`utf8.offset`), never by bytes.
- **Anthropic rate-limits** its usage endpoint below about 5 minutes. Don't poll faster than `FETCH_MS`.
- **Text the user sees** lives in `labels.luau`. Add a key to `en` (and the other languages you can) instead of hard-coding words elsewhere.
- **A widget's `title` is a hover card.** Tern draws each `Key: value` line as a row and any other line as text cut with an ellipsis, in a card about 270 px wide inside. Build it with `card` in `usage.luau`, keep keys and values short, and never put `: ` in a text line (it turns into a row). `tests/usage_test.luau` measures every card in every language.
- **Settings are read outside the render.** `config.load()` reads `tern.kv` at load and on the minute tick; a render only reads the cached table.
- **No credentials, one request.** The plugin runs `omp`, plus a daily unauthenticated GET of this repository's latest GitHub release (off with the `updates` part or `OMP_USAGE_NO_UPDATE_CHECK`). Don't add more network calls; anything that needs a token belongs in `omp`, not here.
- **Write only to `tern.plugin.data`.** An install replaces the package folder, and a write inside it reloads the plugin.

## What the user can configure

The palette: `OMP usage: show or hide a part…` (`alerts`, `updates`), `language…`, `work days per week…`, `red badge threshold…`, `reset settings`, `check for updates`, `update to the latest version`, `what's new`, `dashboard` (settings in `tern.kv`, kept across updates). Which widgets show, in what order and style, is Tern's widget editor (palette › Edit widgets…). The `OMP_USAGE_BIN` environment variable for the `omp` path and `OMP_USAGE_NO_UPDATE_CHECK=1` to stop the release check; personal widgets in an untracked `extras.luau` (shape in the README). Point users there before suggesting a fork.

## Before you propose a change

```sh
python scripts/check.py                # syntax, unit tests, CSS, manifest, changelog
python scripts/check.py --integration  # the whole plugin in a fake Tern (budgets, update, dashboard)
python scripts/check.py --tern         # also reloads the plugin in Tern and reads the log (when Tern is installed)
```

All must end with `all checks passed`. Add a case to `tests/usage_test.luau` when you change what the bar shows, and a scenario to `tests/integration/plugin_test.luau` when a change crosses modules, timers or the update. Fixtures come from real `omp` output: record with `--redact`, then replace every e-mail, account id and org name with fakes. `check.py` fails on any e-mail in `tests/` that isn't `@example.com`; ids and org names are on you.

## When the user hits a bug

Collect these and offer to open the issue for them. Show the text first, and only file it after they agree:

1. `tern plugin list --json`, just the `omp-usage` entry.
2. Lines with `omp-usage` from Tern's log (`%LOCALAPPDATA%\Tern\Logs\tern.log` on Windows).
3. `omp --version`, and whether `omp usage --json -p anthropic` works in a terminal.
4. What the bar shows against what they expected. A screenshot helps.

**Remove emails, account ids, org names and tokens** from `omp usage --json` output before pasting it. That output contains them.

```sh
gh issue create --repo joaodutra88/tern-omp-usage --template bug_report.yml
```

If `gh` can't use the template non-interactively, pass `--title` and `--body` with the same sections as `.github/ISSUE_TEMPLATE/bug_report.yml`.

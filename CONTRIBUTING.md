# Contributing

Issues and pull requests are welcome: bugs, new providers, translations, better colors. If an AI agent is doing the work, have it read [AGENTS.md](AGENTS.md) first.

## Run it locally

```sh
git clone https://github.com/tremklekmz/tern-omp-usage
tern plugin link tern-omp-usage
```

Tern reloads a linked plugin when a file changes. You can also run `tern plugin reload`, then `tern plugin list` to see whether it loaded or was disabled.

## Validate your change

Install the [Luau CLI](https://github.com/luau-lang/luau/releases/latest) (`luau` and `luau-compile` on `PATH`, or set `LUAU_DIR` to their folder), then:

```sh
python scripts/check.py                # syntax, unit tests, CSS rules Tern rejects, manifest, changelog
python scripts/check.py --integration  # the whole plugin in a fake Tern, with recorded omp and GitHub answers
python scripts/check.py --tern         # also reloads the plugin in your Tern and reads its log
```

Each should end with `all checks passed`.

- **Unit** (`tests/*_test.luau`): one module against a fake `tern` with canned `omp` replies. If you change what the bar shows, add a case to `tests/usage_test.luau`.
- **Integration** (`tests/integration/`): `harness.luau` loads `window.luau` and `host.luau` the way Tern does, runs timers and callbacks on a fake clock, answers with the recorded replies in `fixtures.luau`, and can reinstall the plugin. It fails when a callback goes over Tern's budget (the formatter touching a process, file or kv; any other callback starting more than one process) and it refuses an install that runs inside the plugin folder, as Windows does. Add a scenario to `plugin_test.luau` when a change crosses modules, timers or the update.
- **In Tern** (`--tern`): the only check that needs Tern itself. It can't run in CI, because Tern requires a Stencil account, so run it before you ask for a merge when you have Tern.

## What CI runs

On every pull request, `unit` runs first and `integration` runs after it on Linux, Windows and macOS. Both must pass before a merge. On `main` the same jobs run again, and then `release` publishes a GitHub release when `plugin.toml` names a version that has none yet, with that version's `CHANGELOG.md` section as the notes. Luau is pinned in `.github/workflows/check.yml`; Dependabot keeps the actions current.

## Things Tern is strict about

- A status formatter that takes over 4 ms gets the plugin disabled. Slow work (processes, file reads) belongs in timers and process callbacks.
- Tern's CSS engine is a subset. `text-shadow` and `margin-block` are rejected; the check script catches the known ones.
- Text sent to Tern must stay valid UTF-8. Cut by characters, not bytes.

## Translations

Copy the `en` table in `labels.luau`, translate the values, and add the language code to `M.LANGUAGES` in `config.luau`. A key you leave out falls back to English. A `README.<lang>.md` is welcome too, linked from the language line at the top of each README.

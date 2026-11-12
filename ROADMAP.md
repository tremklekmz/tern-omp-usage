# Roadmap

What shipped, what comes next, and the rules every change follows. Ideas and votes go to [Discussions](https://github.com/joaodutra88/tern-omp-usage/discussions); anything marked **good first issue** in [Issues](https://github.com/joaodutra88/tern-omp-usage/issues) is a fine place to start.

## Shipped in 0.5.0

- **Widgets.** The usage leaves Tern's **Plugin segments** widget for widgets of its own, one per answer, which people place, order and style in Tern's widget editor. A new feature is a new widget, so an update never changes someone's bar by surprise.
- **Saved resets**: usable now / saved, and a toast when one becomes usable or a usable one is about to expire.
- **Problems**: a widget and a toast when omp fails or turns a login off.
- **Speed and cache** from `omp stats`.
- **Dashboard for every provider** `omp usage` reports (Gemini, xAI, OpenCode Go…), and the cost by model.
- **"Today" starts at local midnight**, not at midnight UTC.

## Shipped in 0.4.1

- **The one-click update works on Windows.** It ran inside the plugin's own folder, which Windows won't replace. On Windows, 0.4.0 users reinstall by hand once.
- **No more frozen bar after a load.** The load timer started four processes in one callback, Tern's 50 ms ran out, and Tern turned off every timer of the plugin.
- **CI with an integration round.** Every pull request runs the unit tests, then the whole plugin in a fake Tern with recorded `omp` and GitHub answers, on Linux, Windows and macOS. `main` takes a merge only when both pass, and the release waits for them too.

## Shipped in 0.4.0

- **Releases from the manifest.** Bumping `version` in `plugin.toml` on `main` publishes the GitHub release, with that version's section of `CHANGELOG.md` as the notes. `scripts/check.py` fails when the version has no section.
- **Update notice and one-click update.** A daily, unauthenticated look at the latest release; a blue `⬆` and one toast per new version; a click reinstalls the plugin and keeps settings and `extras.luau`; a toast after the update and **OMP usage: what's new**. Off with the `updates` part or `OMP_USAGE_NO_UPDATE_CHECK=1`.
- **Settings without editing code.** Palette commands for the parts shown, the language (`en`, `pt-BR`, `es`, `zh-CN`, `ja`), work days per week and the red-badge threshold, kept in `tern.kv` so updates keep them.
- **A provider you don't use is hidden** instead of showing `?` and `⚠` all the time.
- **Alerts**: a toast when a window reaches the red-badge threshold, locks, or frees up again.
- **Forecast**: `⏳23m` when, at the pace since the window opened, it runs out before its reset.
- **Dashboard**: 7 days of Claude and Codex usage hour by hour, and the cost of today, the last 7 days and this month.

## Next

- [ ] More languages: copy `en` in `labels.luau`, translate, open a pull request.
- [ ] Rendered images of the widgets in each state (calm, rising, hot, over budget, locked), the dashboard and the alert toasts for the README, from canned `omp` replies.

## Rules for every change

- A widget's render gets 4 ms: no process, file or `tern.kv` read inside it (nor inside `tern.chrome.status`). Timers and callbacks get 50 ms: start one process or request per callback at most.
- Widget ids are in people's saved bars: add new ones, never rename or remove one without saying so in the changelog.
- Tern's CSS is a subset; `scripts/check.py` catches the properties it rejects. Strings must be valid UTF-8.
- Every word the plugin shows lives in `labels.luau`.
- The only network request is the daily release check, with no token, and it can be turned off.
- `python scripts/check.py` and `--integration` pass (and `--tern`, when you have Tern), and every new behavior gets a case in `tests/`. Test data comes from real `omp` output with every e-mail, account id and org name replaced by fakes.

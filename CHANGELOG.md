# Changelog

Every version `plugin.toml` names has a section here. When that version reaches `main`, CI publishes the section as the GitHub release, and installed copies of the plugin show it.

## 0.4.2

- Work-week budget: a date counts toward the 7-day window only when the window holds its noon. A window that resets Saturday 21:00 used to count the three hours of the Saturday it opened as a whole day, unlocking one share too many all week; now it runs Sunday to Saturday.
- Updates come from the fork, `tremklekmz/tern-omp-usage`.

## 0.4.1

**On Windows with 0.4.0:** the update button fails with "The process cannot access the file". Run `tern plugin install https://github.com/joaodutra88/tern-omp-usage --force` once; from 0.4.1 on the button works.

- The one-click update works on Windows. The install ran inside the plugin's own folder, which Windows won't let it replace; it now runs from the data folder.
- The bar no longer freezes after a fresh install or a reload. The first timer started four processes at once and went over Tern's 50 ms, so Tern turned off every timer of the plugin. Now each callback starts one at most: Codex after Claude, today's cost and the release check a moment later.
- CI: every pull request runs the unit tests, then an integration round on Linux, Windows and macOS that loads the whole plugin in a fake Tern with recorded `omp` and GitHub answers. It checks Tern's time budgets, the update (with Windows' folder lock), the settings and `extras.luau` surviving it, the alerts and the dashboard. A release is published only after both pass.

## 0.4.0

**Upgrading from 0.3.x:** run `tern plugin install https://github.com/joaodutra88/tern-omp-usage --force` once. From this version on the plugin tells you about new releases and updates itself with one click.

- A provider omp has no account for is hidden. Signed in to Claude only, the bar used to show a permanent `⬢ Codex ?` and `⚠`.
- Settings from the palette (type `OMP usage`): show or hide each part, language (`en`, `pt-BR`, `es`, `zh-CN`, `ja`), work days per week and the red-badge threshold. They live in `tern.kv`, so an update keeps them.
- Every word lives in `labels.luau`; a language that leaves a key out falls back to English.
- Update notice: once a day the plugin looks at the latest GitHub release. A newer one shows a blue `⬆` badge and one toast; clicking it reinstalls the plugin (`tern plugin install … --force`), keeping your settings and `extras.luau`. After the update a toast names the new version, and **OMP usage: what's new** opens its notes. Hide the `updates` part or set `OMP_USAGE_NO_UPDATE_CHECK=1` to stop checking.
- Alerts: a toast when a Claude or Codex window reaches the red-badge threshold, locks, or frees up again. The first reading after a reload only sets the baseline, so a reload never repeats an alert.
- Forecast: `⏳23m` after the Claude 5h or `wk` bar when, at the average pace since that window opened, it runs out before it resets. It shows from 50% used.
- Dashboard: **OMP usage: dashboard**, or a click on today's tokens or cost, opens a pane with Claude and Codex 5h and weekly usage hour by hour over the last 7 days, and the cost of today, the last 7 days and this month. The plugin now keeps each day's total in `tern.kv`, because `omp stats` only goes back about a day.

## 0.3.1

- Finds the omp that Tern manages on macOS (`~/Library/Application Support/Tern/omp/bin/omp`).
- Shows `✻ Claude ?` and `⬢ Codex ?` instead of a stuck `⟳ …` when omp can't start.

## 0.3.0

- First release: Claude and Codex limits from omp in Tern's status line, a work-week budget, saved resets, and today's tokens and cost.

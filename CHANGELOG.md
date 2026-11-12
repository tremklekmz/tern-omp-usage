# Changelog

Every version `plugin.toml` names has a section here. When that version reaches `main`, CI publishes the section as the GitHub release, and installed copies of the plugin show it.

## 0.6.2

- Clicking a widget no longer makes Claude or Codex vanish. The click clears omp's cache, Anthropic refuses a read that soon, and omp answers without a report but with the account under `accountsWithoutUsage`; the plugin took that for "no account" and hid its widgets. It now keeps the last reading and **Problems** shows the failed read until one succeeds.
- Work-week budget: a date counts toward the 7-day window only when the window holds its noon. A window that resets Saturday 21:00 used to count the three hours of the Saturday it opened as a whole day, unlocking one share too many all week; now it runs Sunday to Saturday.
- Updates come from the fork, `tremklekmz/tern-omp-usage`.

## 0.6.1

- The provider's icon shows on the 5h widget only: wk and Fable, placed beside it, no longer repeat it (Codex wk too).

## 0.6.0

- Hovering a widget opens a card instead of a line of text: Tern's own hover card, one row per detail, sized to fit in every language.
- Limits: the card has the share used and the reset; Claude's, from 10 minutes into the window and at any share used, adds when the window runs out at the average pace so far, with the verdict: the reset comes first, or it runs out so long before it.
- **Tokens today**: the card adds the tokens since Monday, from the days Tern was open, and today's requests.
- **Problems**: a cause omp reports over several lines (a provider's JSON error) stays on one line of the card.

## 0.5.0

**Coming from 0.4.x:** the usage leaves the **Plugin segments** widget and becomes widgets of its own, so after the update the bar is empty until you place them: palette › **Edit widgets…**. Needs Tern 0.9.17 or later.

- Widgets: Claude 5h, wk and Fable and Codex 5h and wk (five colored dots beside the provider's icon, like the old status line), work-week budget (text or bar), runs out, saved resets, tokens and cost today (text, or a graph of the running total), speed and cache, problems and plugin update. Pick, order and style them in Tern's widget editor; hover one for its details.
- Saved resets show usable now / saved, from omp's `redeemableCount`. A toast when one becomes usable, and when a usable one expires within 2 days; the tooltip lists what each one clears and when it expires.
- **Problems**: shows up, with a toast, when omp turns a login off (a failed OAuth refresh, say) or an `omp usage` call fails. The cause shows without the account's e-mail.
- **Speed and cache**: average tok/s and cache hit rate from `omp stats`.
- The dashboard shows every provider omp tracks (Gemini, xAI, OpenCode Go…), not only Claude and Codex, and the cost by model. A quota omp reports twice (Antigravity's shared Claude & GPT) shows once.
- Fix: "today" (tokens, cost and the day kept for the dashboard) started at midnight UTC instead of local midnight: at 21:00 the evening before in Brazil.
- **OMP usage: show or hide a part…** keeps `alerts` and `updates`; what the bar shows is the widgets you place.
- `extras.luau` can register widgets with `tern.chrome.widget`; `M.segments` is optional and still fills **Plugin segments**.

## 0.4.4

- Tern 0.9.17 turned the status line into the widget bar and every plugin segment into a chip (a grey dot, a pill, smaller text) that ignored the plugin's colors and spacing. The stylesheet now targets the widget bar, so the bar looks as before, inside the **Plugin segments** widget (palette › **Edit widgets…**). Needs Tern 0.9.17 or later.
- `extras.luau`: style a segment with `#widgetbar .wg-seg[title="plugin.omp-usage.<name>"]`; `#statusline` no longer matches anything.

## 0.4.3

- German (`de`) and French (`fr`) in **OMP usage: language…**.
- CI: `actions/checkout` 7 and `actions/setup-python` 7, off the deprecated Node 20.

## 0.4.2

- Tern 0.9.16 moved the plugin segments into a group inside the status bar, so the rule that zeroes Tern's gap stopped matching and every segment drifted apart: the dots of a meter, a label from its value. The rule now matches at any depth and the bar looks as before.

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

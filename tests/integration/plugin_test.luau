-- The whole plugin in a fake Tern (harness.luau): both halves load, timers and callbacks run on a fake clock, and
-- omp and GitHub answer with recorded replies. Every scenario ends checking Tern's budgets and that nothing raised.
-- Run: python scripts/check.py --integration
local H = require("./harness")
local expect = H.expect

local function clean(w: any)
	expect(#w.errors == 0, "no callback raised", table.concat(w.errors, "\n"))
	expect(#w.violations == 0, "no callback over Tern's budget", table.concat(w.violations, "\n"))
end

local function has(text: string, part: string): boolean
	return string.find(text, part, 1, true) ~= nil
end

-- A fresh install: the omp Tern manages answers, the widgets fill in, and three fetch rounds stay within budget.
do
	local w = H.world()
	w:load()
	w:run(10000)
	local text = w:bar()
	expect(w.spawned[1].argv[1] == H.OMP, "the omp that Tern manages is the one that runs", w.spawned[1].argv[1])
	expect(has(text, "11%") and has(text, "20%"), "Claude 5h and week from the recorded answer", text)
	expect(w:widget("codex-5h") and has(w:widget("codex-5h").title, "Accounts: 2"), "Codex with its two accounts", text)
	expect(has(text, "$12"), "today's cost leaves out yesterday's bucket", text)
	expect(not has(text, "⬆"), "no update badge", text)
	local health = w:widget("health")
	expect(health and has(health.text, "Codex off") and has(health.title, "Codex: login off\noauth refresh failed · 401"), "the login omp turned off shows", health and health.title)
	expect(not has(health.title, "@"), "without the account's e-mail", health.title)
	expect(#w.toasts == 0, "a first install shows no toast", w:toast_texts())
	local today = os.date("%Y-%m-%d") :: string
	expect(w.kv.days and w.kv.days[today] and w.kv.days[today].cost == 12.4, "today's total is kept for the dashboard")
	w:run(3 * H.FETCH_MS)
	expect(#w.toasts == 0, "a login that was already off doesn't toast again", w:toast_texts())
	clean(w)
end

-- A provider with no account is hidden; an omp that can't start shows the warning instead of stale numbers.
do
	local w = H.world()
	w.replies["usage --json -p openai-codex"] =
		'{"generatedAt": @T+0@, "reports": [], "accountsWithoutUsage": [], "disabledCredentials": [], "capacity": {}}'
	w:load()
	w:run(10000)
	local text = w:bar()
	expect(w:widget("codex-5h") == nil and not has(text, "⚠"), "Codex without an account is hidden, not an error", text)
	clean(w)

	w = H.world()
	w.omp_missing = true
	w:load()
	w:run(10000)
	expect(has(w:bar(), "⚠"), "a missing omp shows the warning", w:bar())
	clean(w)
end

-- Alerts: the first reading only sets the baseline; climbing to 85%, locking and freeing up toast once each.
do
	local w = H.world()
	w.vars.C5 = 0.5
	w:load()
	w:run(10000)
	expect(#w.toasts == 0, "the first reading sets the baseline", w:toast_texts())
	w.vars.C5 = 0.85
	w:run(H.FETCH_MS)
	w:run(H.FETCH_MS) -- same level again: silent
	w.vars.C5 = 1
	w:run(H.FETCH_MS)
	expect(has(w:bar(), "5h LOCKED"), "a full window shows the lock", w:bar())
	w.vars.C5 = 0.1
	w:run(H.FETCH_MS)
	local toasts = w:toast_texts()
	expect(#w.toasts == 3, "three alerts, one per change", toasts)
	expect(has(toasts, "Claude 5h at 85%") and has(toasts, "Claude 5h is locked") and has(toasts, "Claude 5h is free again"), "threshold, lock and free", toasts)
	clean(w)
end

-- The update: a newer release shows the badge, a click reinstalls from GitHub, and the settings and extras.luau
-- survive a package folder that comes back without them. The fake Tern refuses an install whose working
-- directory is the plugin folder, as Windows does.
do
	local EXTRAS = 'return { init = function() end, segments = function(out) table.insert(out, { text = "EXTRA " }) end }'
	local w = H.world({ extras = EXTRAS })
	w:load()
	w:run(10000)
	expect(has(w:bar(), "EXTRA"), "extras.luau beside window.luau loads", w:bar())
	table.insert(w.answers, "pt-BR")
	w:click("plugin.omp-usage.settings-language")
	w:run(100)
	expect(has(w:bar(), "sobra"), "the language setting applies", w:bar())

	w.vars.VERSION = "9.9.9"
	w:click("plugin.omp-usage.check-update")
	w:run(100)
	local text, cmd = w:bar()
	expect(has(text, "⬆ 9.9.9") and cmd["plugin.omp-usage.update"], "a newer release shows the badge", text)
	expect(has(w:toast_texts(), "Saiu o OMP usage 9.9.9"), "and says so", w:toast_texts())

	w:click("plugin.omp-usage.update")
	w:run(10000)
	local toasts = w:toast_texts()
	expect(not has(toasts, "falhou"), "the reinstall succeeds", toasts)
	expect(w.installed_from == H.SOURCE, "it installs from the repository", w.installed_from)
	expect(w.files["extras.luau"] == nil, "the new package has no extras.luau")
	text = w:bar()
	expect(has(text, "EXTRA"), "extras.luau comes back from the data folder", text)
	expect(has(text, "sobra"), "the language survives the update", text)
	expect(not has(text, "⬆"), "the badge is gone", text)
	expect(has(toasts, "OMP usage atualizado para 9.9.9"), "the new version says it is running", toasts)
	w:run(2 * H.FETCH_MS)
	clean(w)
end

-- The dashboard: a click on the cost widget opens it with the history and the week's cost; a click on the tokens
-- focuses the same pane; `r` reads the history again. No e-mail or account id from the history reaches the view.
do
	local w = H.world()
	w:load()
	w:run(10000)
	w:click(w:widget("cost").command)
	w:run(1000)
	local id = w.focused
	expect(id ~= nil and w.panes[id] ~= nil, "the cost widget opens the dashboard")
	local view = w:view(id)
	expect(has(view, "Claude") and has(view, "Codex") and has(view, "5h") and has(view, "wk"), "both providers' windows", view)
	expect(has(view, "Today") and has(view, "$12"), "today's cost", view)
	expect(not has(view, "@") and not has(view, "acct-"), "no e-mail or account id", view)

	w:click(w:widget("today").command)
	w:run(100)
	local open = 0
	for _ in w.panes do
		open += 1
	end
	expect(open == 1 and w.focused == id, "a second click focuses the open dashboard", open)

	local before = #w.spawned
	w:key(id, "r")
	w:run(1000)
	expect(#w.spawned > before and w.spawned[before + 1].argv[3] == "--history", "r reads the history again")
	clean(w)
end

print("plugin_test: ok")

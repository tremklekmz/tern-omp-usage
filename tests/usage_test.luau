-- Runs usage.luau against a fake `tern` with canned `omp` replies and checks what each widget shows.
-- Run: luau tests/usage_test.luau (from the repository root, or via scripts/check.py).

local now_ms = os.time() * 1000
local DAY = 86400 * 1000

local replies: { [string]: any } = {}
local spawn_fails = false

local function reply(argv: { string }): string
	return table.concat(argv, " ", 2)
end

local store: { [string]: any } = {}
local widgets: { [string]: any } = {}
local sheets: { [string]: string } = {}

local toasts: { { string } } = {}
local window_cx = {
	toast = function(_self, level: string, text: string, sub: string?)
		table.insert(toasts, { level, text, sub or "" })
	end,
}

local fake = {
	kv = {
		get = function(key: string)
			return store[key]
		end,
		set = function(key: string, value: any)
			store[key] = value
		end,
	},
	timer = function(_ms: number, fn: () -> ())
		fn()
	end,
	chrome = {
		refresh = function() end,
		widget = function(id: string, spec: any)
			assert(string.match(id, "^[a-z][a-z0-9-]*$") and #id <= 32, "bad widget id " .. id)
			assert(type(spec.name) == "string" and type(spec.render) == "function", id .. " needs a name and render")
			widgets[id] = spec
		end,
	},
	css = function(name: string, source: string)
		sheets[name] = source
	end,
	json = {
		decode = function(key: string)
			return assert(replies[key], "no canned reply for: " .. key)
		end,
	},
	process = {
		run = function(argv: { string }, opts, done)
			if spawn_fails then
				error("tern.process.run omp: No such file or directory (os error 2)")
			end
			local cb = if type(opts) == "function" then opts else done
			cb({ status = 0, stdout = reply(argv) }, window_cx)
		end,
	},
}
local usage = require("../usage")
local config = require("../config")
local history = require("../history")
-- Why: the luau CLI freezes _G; each module's own environment stays writable and is read at call time.
for _, f in { usage.fetch, config.load, history.name } do
	local env: any = getfenv(f)
	env.tern = fake
end
config.load()
usage.widgets()

local t = os.date("*t") :: any
local midnight_ms = (os.time() - (t.hour * 3600 + t.min * 60 + t.sec)) * 1000

local function claude(five: number, week: number, week_reset: number, extra: { any }?, credits: any?)
	local limits = {
		-- 30 s past 1h30m, so a second ticking during the test still reads "1h30m".
		{ id = "anthropic:5h", amount = { usedFraction = five }, window = { resetsAt = now_ms + 90 * 60 * 1000 + 30000 } },
		{ id = "anthropic:7d", amount = { usedFraction = week }, window = { resetsAt = week_reset } },
	}
	for _, l in extra or {} do
		table.insert(limits, l)
	end
	return { reports = { { limits = limits, resetCredits = credits or { availableCount = 1 } } } }
end

local codex = {
	reports = {
		{
			limits = {
				{ id = "openai-codex:primary", window = { resetsAt = now_ms + DAY } },
				{ id = "openai-codex:secondary", window = { resetsAt = now_ms + 3 * DAY } },
			},
			resetCredits = { availableCount = 2 },
		},
		{ limits = {}, resetCredits = { availableCount = 1 } },
	},
	capacity = {
		["openai-codex"] = {
			{ window = "5h", accounts = 2, usedAccounts = 0.5 },
			{ window = "7d", accounts = 2, usedAccounts = 1 },
		},
	},
}

local stats = {
	overall = { avgTokensPerSecond = 78.9, avgTtft = 2770, cacheRate = 0.99, cacheSavings = 0.89, firstTimestamp = now_ms - DAY },
	timeSeries = {
		{ timestamp = midnight_ms - 3600000, tokens = 9000000, cost = 80, requests = 900 },
		{ timestamp = now_ms, tokens = 1500000, cost = 12.4, requests = 120 },
	},
}

-- Every widget's view after one fetch round, and all their texts in one line.
local function render(claude_reply, codex_reply: any?): ({ [string]: any }, string)
	replies["usage --json -p anthropic"] = claude_reply
	replies["usage --json -p openai-codex"] = codex_reply or codex
	replies["stats --json"] = stats
	usage.fetch()
	usage.fetch_today()
	local views, texts = {}, {}
	for id, spec in widgets do
		local v = spec.render(nil)
		views[id] = v
		if v then
			assert(type(v.text) == "string", id .. " shows no text")
			table.insert(texts, v.text)
		end
	end
	table.sort(texts)
	return views, table.concat(texts, " | ")
end

local function expect(cond: any, msg: string, text: string?)
	if not cond then
		error(msg .. "\n  got: " .. tostring(text), 2)
	end
end

local function has(s: string?, part: string): boolean
	return s ~= nil and string.find(s, part, 1, true) ~= nil
end

-- The CSS rule that paints one limit widget, from the last sheet usage.luau installed ("" when it isn't painted).
local function rule(id: string): string
	local quoted = string.gsub(id, "%-", "%%-")
	return string.match(sheets.dots or "", "%[data%-widget='omp%-usage/" .. quoted .. "'%][^\n]*") or ""
end

-- omp missing: tern.process.run raises instead of calling back; the limits show '?', Problems says so, and the
-- next round still runs.
spawn_fails = true
usage.fetch(true)
usage.fetch_today()
local c5 = widgets["claude-5h"].render(nil)
expect(c5 and c5.text == "5h ?" and c5.tone == "error" and c5.icon == "provider-anthropic", "Claude should show '?' and its icon when omp can't start", c5 and c5.text)
expect(widgets["codex-5h"].render(nil).text == "5h ?", "Codex should show '?' when omp can't start")
expect(widgets["claude-fable"].render(nil) == nil, "Fable stays hidden when omp fails")
expect(has(widgets.health.render(nil).text, "omp ?"), "Problems shows the failed fetch")
spawn_fails = false

-- The 7d window starting right now leaves at most one weekday unlocked (20%), so 0% used is never over budget.
local v, text = render(claude(0.4, 0, now_ms + 7 * DAY))
expect(v["claude-5h"].text == "5h ●●●●● 40%" and v["claude-5h"].icon == "provider-anthropic", "Claude 5h", text)
expect(v["claude-week"].icon == nil and v["codex-week"].icon == nil, "only the 5h widget carries the provider's icon", v["claude-week"].icon)
-- 40% reaches the second of five dots: dots 1–2 green and lime, 3–5 dim, the share in lime, stops up to the end.
local r = rule("claude-5h")
expect(has(r, "#22c55e") and has(r, "#a3e635") and not has(r, "#facc15") and has(r, "100.000%"), "the dots are painted", r)
expect(has(sheets.dots, "omp-usage/claude-'] .wg-ico { color: #d97757"), "the Claude icon wears Claude's color", sheets.dots)
expect(has(v["claude-5h"].title, "Used: 40%\nResets in: 1h30m\n"), "the card has the share used and the 5h reset", v["claude-5h"].title)
-- 3h29m into the 5h window at 40%, the average pace lasts 5h14m more: the reset comes first.
expect(has(v["claude-5h"].title, "At this pace, out in: 5h14m\nResets before it runs out"), "the pace shows under 50% too", v["claude-5h"].title)
expect(v["claude-5h"].command == "plugin.omp-usage.refresh", "a limit refreshes on click", v["claude-5h"].command)
expect(has(v.budget.text, "📅 left") and v.budget.tone == "ok", "budget should be 'left' at 0% weekly use", text)
expect(v["claude-fable"] == nil, "Fable must stay hidden when the plan has no Fable window", text)
expect(v.resets.text == "✦ 4" and v.resets.tone == "accent", "Claude's 1 and Codex's 2 + 1 saved resets", text)
expect(v["codex-5h"].text == "5h ●●●●● 25%" and v["codex-5h"].icon == "provider-openai-codex", "Codex 5h should be usedAccounts/accounts = 25%", text)
expect(has(v["codex-5h"].title, "Accounts: 2"), "Codex account count in the card", v["codex-5h"].title)
expect(has(v.cost.title, "Today: $12\nLast 7 days: $"), "the cost card has a row per period", v.cost.title)
expect(v.today.text == "🔥 2M" and v.cost.text == "💸 $12", "today's tokens and cost leave out yesterday's bucket", text)
expect(#v.cost.series >= 42 and v.cost.series[#v.cost.series] == 1, "the cost graph spans its width and ends at the day's total", #v.cost.series)
expect(v.speed.text == "⚡ 79 tok/s · ♻ 99%" and v.speed.value == 0.99, "speed and cache rate", v.speed and v.speed.text)
expect(v.health == nil and v.forecast == nil, "no problem and no forecast under 50%", text)

-- A rise of 3 points or more between two fetches earns the arrow; holding still drops it.
v = render(claude(0.45, 0, now_ms + 7 * DAY))
expect(v["claude-5h"].text == "5h ●●●●● 45%↑", "rising shows ↑", v["claude-5h"].text)
v = render(claude(0.45, 0, now_ms + 7 * DAY))
expect(v["claude-5h"].text == "5h ●●●●● 45%", "holding still drops ↑", v["claude-5h"].text)

-- 100% of the week with only today unlocked: over budget, and the week is locked until its reset.
v, text = render(claude(0.5, 1, now_ms + 7 * DAY, {
	{ id = "anthropic:7d:fable", amount = { usedFraction = 0.1 }, window = { resetsAt = now_ms + 7 * DAY } },
}))
expect(has(v.budget.text, "📅 over") and v.budget.tone == "error", "budget should be 'over' at 100% weekly use", text)
expect(has(v["claude-week"].text, "wk LOCKED") and v["claude-week"].tone == "error", "the lock shows at 100%", text)
expect(rule("claude-week") == "", "a locked window wears the error tone, not the dots", rule("claude-week"))
expect(v["claude-fable"] and v["claude-fable"].text == "Fable ●●●●● 10%" and v["claude-fable"].icon == nil, "Fable shows when the plan has it, without the icon", text)

-- Signed in to Claude only: omp answers Codex with no reports, which hides its widgets rather than flagging an error.
v, text = render(claude(0.4, 0, now_ms + 7 * DAY), { reports = {}, capacity = {} })
expect(v["codex-5h"] == nil and v["codex-week"] == nil, "Codex should hide when omp has no Codex account", text)
expect(v.health == nil, "a provider without an account is not a problem", text)
expect(v["claude-5h"] ~= nil, "Claude stays when only Codex has no account", text)

-- A read omp couldn't make (rate-limited after a click's invalidate) lists the account without a report: the last
-- reading stays and Problems flags the failed read, instead of the widgets vanishing as if there were no account.
render(claude(0.4, 0, now_ms + 7 * DAY))
v, text = render({ reports = {}, accountsWithoutUsage = { { provider = "anthropic" } } }, {
	reports = {},
	accountsWithoutUsage = { { provider = "openai-codex" } },
})
expect(v["claude-5h"] and has(v["claude-5h"].text, "40%"), "an unread Claude account keeps the last reading", text)
expect(v["codex-5h"] ~= nil, "an unread Codex account keeps the last reading", text)
expect(v.health and v.health.tone == "error" and has(v.health.title, "Claude") and has(v.health.title, "Codex"), "Problems flags both failed reads", v.health and v.health.title)
render(claude(0.4, 0, now_ms + 7 * DAY))

-- Settings: each answer is what the palette prompt receives.
local function settle(answer: string, input: string): boolean
	local ok = config.answer[answer](input)
	return ok
end

expect(settle("language", "pt-br"), "language codes match case-insensitively")
v = render(claude(0, 0, now_ms + 7 * DAY))
expect(has(v.budget.text, "📅 sobra"), "pt-BR should show its own words", v.budget.text)
usage.widgets()
expect(widgets.budget.name == "Orçamento da semana útil", "registering again renames the widget for the gallery", widgets.budget.name)
settle("language", "ja")
v = render(claude(0, 0, now_ms + 7 * DAY))
expect(has(v.budget.text, "📅 残り"), "ja should show its own words", v.budget.text)
expect(not settle("language", "klingon"), "an unknown language is refused")

-- A reinstall keeps the data folder: loading the store again restores the language.
config.load()
v = render(claude(0, 0, now_ms + 7 * DAY))
expect(has(v.budget.text, "📅 残り"), "settings should survive a fresh load from tern.kv", v.budget.text)
settle("language", "en")
usage.widgets()

expect(not settle("part", "codex"), "the widget bar places the limits now, so they are not parts")
expect(not settle("part", "weather"), "an unknown part is refused")

-- With all 7 days counting, each date the window holds at noon unlocks 1/7. Resets are pinned to a clock time, since
-- whether the window's first date counts depends on it.
settle("workdays", "7")
-- Opened two days ago at 03:00: that date, yesterday and today, 3/7.
v = render(claude(0, 0, midnight_ms + 5 * DAY + 3 * 3600 * 1000))
expect(v.budget.text == "📅 left 43%", "a morning reset counts the date the window opened", v.budget.text)
-- Opened two days ago at 21:00: those three hours belong to the window's last date, so yesterday and today, 2/7.
v = render(claude(0, 0, midnight_ms + 5 * DAY + 21 * 3600 * 1000))
expect(v.budget.text == "📅 left 29%", "an evening reset leaves the date the window opened out", v.budget.text)
expect(not settle("workdays", "8"), "more than 7 work days is refused")

settle("crit", "60%")
v = render(claude(0.65, 0, now_ms + 7 * DAY))
expect(has(rule("claude-5h"), "#ef4444"), "65% is critical with the threshold at 60%: the share turns red", rule("claude-5h"))
expect(not settle("crit", "20"), "a threshold under 50% is refused")

config.reset()
v = render(claude(0.65, 0, now_ms + 7 * DAY))
expect(not has(rule("claude-5h"), "#ef4444"), "reset brings the threshold back to 80%", rule("claude-5h"))
expect(store.settings ~= nil and next(store.settings) == nil, "reset leaves an empty store")

-- Alerts: climbing to the threshold, locking and freeing up each toast once; holding a level says nothing.
toasts = {}
render(claude(0.85, 0, now_ms + 7 * DAY))
expect(#toasts == 1 and toasts[1][2] == "Claude 5h at 85%", "climbing to 80% toasts once", toasts[1] and toasts[1][2])
expect(toasts[1][3] == "resets in 1h30m", "the toast says when the window resets", toasts[1][3])
render(claude(0.9, 0, now_ms + 7 * DAY))
expect(#toasts == 1, "staying above the threshold says nothing")
render(claude(1, 0, now_ms + 7 * DAY))
expect(toasts[2] and toasts[2][1] == "error" and toasts[2][2] == "Claude 5h is locked", "locking toasts an error")
render(claude(0.1, 0, now_ms + 7 * DAY))
expect(toasts[3] and toasts[3][2] == "Claude 5h is free again", "freeing up toasts")
settle("part", "alerts")
render(claude(0.85, 0, now_ms + 7 * DAY))
expect(#toasts == 3, "alerts off means no toast")
settle("part", "alerts")

-- Forecast: at 90% with the reset 90 min away (3.5 h into the 5h window), the average pace runs out in 23 min.
v = render(claude(0.9, 0, now_ms + 7 * DAY))
expect(v.forecast and v.forecast.text == "⏳ 5h 23m", "the 5h window shows when it runs out", v.forecast and v.forecast.text)
expect(has(v["claude-5h"].title, "At this pace, out in: 23m\nRuns out 1h07m before the reset"), "and its card says how long before the reset", v["claude-5h"].title)
v = render(claude(0.4, 0, now_ms + 7 * DAY))
expect(v.forecast == nil, "under 50% there is no forecast")
-- Half the week gone in two days runs out in two more, before the reset five days away.
v = render(claude(0.1, 0.5, now_ms + 5 * DAY))
expect(v.forecast and v.forecast.text == "⏳ wk 2d00h", "the week shows when it runs out", v.forecast and v.forecast.text)

-- Saved resets: omp's redeemableCount says how many are usable now; one turning usable toasts, and one close to
-- expiring toasts once, across restarts.
local function credit(id: string, usable: boolean, expires_s: number): any
	return {
		id = id,
		status = "available",
		usable = usable,
		clears = { "anthropic:5h", "anthropic:7d" },
		expiresAt = os.date("!%Y-%m-%dT%H:%M:%S.000Z", expires_s),
	}
end
local no_codex = { reports = {}, capacity = {} }
local later = os.time() + 20 * 86400
toasts = {}
v = render(claude(0.1, 0, now_ms + 7 * DAY, nil, { availableCount = 2, redeemableCount = 0, credits = { credit("c1", false, later), credit("c2", false, later) } }), no_codex)
expect(v.resets.text == "✦ 0/2" and v.resets.tone == "muted", "saved but none usable yet", v.resets.text)
expect(has(v.resets.title, "Claude 5h, wk: later · ") and not has(v.resets.title, "now ·"), "the card lists each reset", v.resets.title)
expect(#toasts == 0, "fewer usable resets say nothing", toasts[1] and toasts[1][2])
local soon = credit("c1", true, os.time() + 86400)
render(claude(0.1, 0, now_ms + 7 * DAY, nil, { availableCount = 2, redeemableCount = 1, credits = { soon, credit("c2", false, later) } }), no_codex)
expect(toasts[1] and toasts[1][2] == "Claude: 1 saved reset(s) usable now", "a reset turning usable toasts", toasts[1] and toasts[1][2])
expect(toasts[2] and has(toasts[2][2], "Claude: a saved reset expires on "), "a usable reset expiring within 2 days toasts", toasts[2] and toasts[2][2])
render(claude(0.1, 0, now_ms + 7 * DAY, nil, { availableCount = 2, redeemableCount = 1, credits = { soon, credit("c2", false, later) } }), no_codex)
expect(#toasts == 2, "each alert shows once", #toasts)
-- omp before redeemableCount: every saved reset counts as usable.
v = render(claude(0.1, 0, now_ms + 7 * DAY, nil, { availableCount = 3 }), no_codex)
expect(v.resets.text == "✦ 3", "no redeemableCount means all usable", v.resets.text)

-- A login omp turns off: Problems shows it without the account's e-mail, and it toasts once. The cause carries the
-- provider's JSON body over several lines, as omp reports it; the card keeps it on one text line.
toasts = {}
local off = { reports = {}, capacity = {}, disabledCredentials = {
	{ provider = "openai-codex", cause = 'oauth refresh failed for user@example.com: 401 {\n  "error": {\n    "message": "expired"', email = "user@example.com" },
} }
v = render(claude(0.1, 0, now_ms + 7 * DAY), off)
expect(v.health and v.health.text == "⚠ Codex off" and v.health.tone == "error", "Problems names the login", v.health and v.health.text)
expect(has(v.health.title, "401") and not has(v.health.title, "@"), "the cause stays, the e-mail goes", v.health.title)
expect(v.health.title == 'Codex: login off\noauth refresh failed for … · 401 { "error" · { "message" · "expired"\nClick to retry', "the cause is one text line", v.health.title)
expect(#toasts == 1 and toasts[1][2] == "omp turned off the Codex login" and not has(toasts[1][3], "@"), "one toast for it", toasts[1] and toasts[1][2])
render(claude(0.1, 0, now_ms + 7 * DAY), off)
expect(#toasts == 1, "the same login doesn't toast again", #toasts)

-- Today's total goes to tern.kv under its local date, for the dashboard; days older than 62 are dropped.
local today_key = os.date("%Y-%m-%d") :: string
store.days = { ["2000-01-01"] = { tokens = 1, cost = 1 } }
render(claude(0.1, 0, now_ms + 7 * DAY))
expect(store.days[today_key] and store.days[today_key].cost == 12.4, "today's cost is stored for the dashboard")
expect(store.days["2000-01-01"] == nil, "days older than 62 are dropped")

-- The tokens card adds the week since Monday from the days kept: a Monday entry counts (unless Monday is today,
-- whose entry the fetch just wrote), last Sunday's doesn't.
local since = ((os.date("*t") :: any).wday + 5) % 7
local monday = os.date("%Y-%m-%d", os.time() - since * 86400) :: string
local sunday = os.date("%Y-%m-%d", os.time() - (since + 1) * 86400) :: string
store.days = { [monday] = { tokens = 2500000, cost = 1 }, [sunday] = { tokens = 100000000, cost = 1 } }
v = render(claude(0.1, 0, now_ms + 7 * DAY))
local week = if since == 0 then "2M" else "4M"
expect(v.today.title == "Today: 2M tokens\nSince Monday: " .. week .. " tokens\nRequests today: 120", "today, the week since Monday and today's requests", v.today.title)

-- Every card fits Tern's, 296 px wide with 12 px of padding a side, in every language. Estimated widths: 6.6 px a
-- character in the 12 px sans of keys and text lines, 6.9 px in the 11.5 px mono of values, twice that for CJK,
-- 8 px between key and value. This measures the labels: omp's cause is free text, so Tern cuts it with an
-- ellipsis, and here it is short.
local function width(s: string, per: number): number
	local w = 0
	for _, c in utf8.codes(s) do
		w += if c >= 0x2E80 then 2 * per else per
	end
	return w
end
local function overflow(title: string?): string?
	for line in string.gmatch(title or "", "[^\n]+") do
		local k, val = string.match(line, "^(.-): (.*)$")
		if (if k then width(k, 6.6) + 8 + width(val, 6.9) else width(line, 6.6)) > 272 then
			return line
		end
	end
	return nil
end
local brief_off = { reports = {}, capacity = {}, disabledCredentials = {
	{ provider = "openai-codex", cause = "oauth refresh failed: 401" },
} }
local busy_week = claude(0.9, 0.5, now_ms + 5 * DAY, {
	{ id = "anthropic:7d:fable", amount = { usedFraction = 0.6 }, window = { resetsAt = now_ms + 5 * DAY } },
}, { availableCount = 2, redeemableCount = 1, credits = { credit("c3", true, later), credit("c4", false, later) } })
for _, language in config.LANGUAGES do
	settle("language", language)
	for _, round in { { claude(0.4, 0.45, now_ms + 5 * DAY) }, { busy_week }, { claude(0.5, 1, now_ms + 7 * DAY), brief_off } } do
		v = render(round[1], round[2])
		for id, view in v do
			local line = overflow(view.title)
			expect(line == nil, language .. ": the " .. id .. " card fits", line)
		end
	end
	-- omp failing on both: Problems lists each with the retry hint.
	spawn_fails = true
	usage.fetch(true)
	spawn_fails = false
	local line = overflow(widgets.health.render(nil).title)
	expect(line == nil, language .. ": the failed fetch's card fits", line)
end
settle("language", "en")

print("usage_test: ok")

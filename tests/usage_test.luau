-- Runs usage.luau against a fake `tern` with canned `omp` replies and checks what the bar draws.
-- Run: luau tests/usage_test.luau (from the repository root, or via scripts/check.py).

local now_ms = os.time() * 1000
local DAY = 86400 * 1000

local replies: { [string]: any } = {}
local spawn_fails = false

local function reply(argv: { string }): string
	return table.concat(argv, " ", 2)
end

local store: { [string]: any } = {}

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
	chrome = { refresh = function() end },
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
-- Why: the luau CLI freezes _G; each module's own environment stays writable and is read at call time.
local env: any = getfenv(usage.fetch)
env.tern = fake
local config_env: any = getfenv(config.load)
config_env.tern = fake
config.load()

local function claude(five: number, week: number, week_reset: number, extra: { any }?)
	local limits = {
		{ id = "anthropic:5h", amount = { usedFraction = five }, window = { resetsAt = now_ms + 90 * 60 * 1000 } },
		{ id = "anthropic:7d", amount = { usedFraction = week }, window = { resetsAt = week_reset } },
	}
	for _, l in extra or {} do
		table.insert(limits, l)
	end
	return { reports = { { limits = limits, resetCredits = { availableCount = 1 } } } }
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

local function render(claude_reply, codex_reply: any?): (string, { [string]: boolean })
	replies["usage --json -p anthropic"] = claude_reply
	replies["usage --json -p openai-codex"] = codex_reply or codex
	replies["stats --json"] = { timeSeries = { { timestamp = now_ms, tokens = 1500000, cost = 12.4 } } }
	usage.fetch()
	usage.fetch_today()
	local out = {}
	usage.segments(out)
	local texts, commands = {}, {}
	for _, s in out do
		table.insert(texts, s.text)
		if s.command then
			commands[s.command] = true
		end
	end
	return table.concat(texts, " "), commands
end

local function expect(cond: boolean, msg: string, text: string)
	if not cond then
		error(msg .. "\n  bar: " .. text, 2)
	end
end

-- omp missing: tern.process.run raises instead of calling back; the bar must show '?' and stay retryable.
spawn_fails = true
usage.fetch(true)
usage.fetch_today()
local failed_out = {}
usage.segments(failed_out)
local failed_texts = {}
for _, s in failed_out do
	table.insert(failed_texts, s.text)
end
local failed_text = table.concat(failed_texts, " ")
expect(failed_text:find("✻ Claude ?", 1, true) ~= nil, "Claude should show '?' when omp can't start", failed_text)
expect(failed_text:find("⬢ Codex ?", 1, true) ~= nil, "Codex should show '?' when omp can't start", failed_text)
expect(failed_text:find("⟳ …", 1, true) == nil, "a failed spawn must not leave the bar busy", failed_text)
spawn_fails = false

-- The 7d window starting right now leaves at most one weekday unlocked (20%), so 0% used is never over budget.
local text, cmd = render(claude(0.4, 0, now_ms + 7 * DAY))
expect(text:find("✻ Claude", 1, true) ~= nil, "Claude group missing", text)
expect(text:find("40%", 1, true) ~= nil, "5h percentage missing", text)
expect(text:find("📅 left", 1, true) ~= nil, "budget should be 'left' at 0% weekly use", text)
expect(text:find("Fable", 1, true) == nil, "Fable must stay hidden when the plan has no Fable window", text)
expect(text:find("reset 1h", 1, true) ~= nil, "5h reset countdown missing", text)
expect(text:find("✦1", 1, true) ~= nil, "Claude saved reset missing", text)
expect(text:find("⬢ Codex", 1, true) ~= nil, "Codex group missing", text)
expect(text:find("×2", 1, true) ~= nil, "Codex account count missing", text)
expect(text:find("25%", 1, true) ~= nil, "Codex 5h should be usedAccounts/accounts = 25%", text)
expect(text:find("✦3", 1, true) ~= nil, "Codex saved resets should sum over accounts", text)
expect(text:find("🔥 2M tokens", 1, true) ~= nil, "today's tokens missing", text)
expect(text:find("💸 $12", 1, true) ~= nil, "today's cost missing", text)
expect(cmd["plugin.omp-usage.locked"] == nil, "nothing is at 100%, no lockout badge", text)

-- 100% of the week with only today unlocked: over budget, and Claude is locked.
text, cmd = render(claude(0.5, 1, now_ms + 7 * DAY, {
	{ id = "anthropic:7d:fable", amount = { usedFraction = 0.1 }, window = { resetsAt = now_ms + 7 * DAY } },
}))
expect(text:find("📅 over", 1, true) ~= nil, "budget should be 'over' at 100% weekly use", text)
expect(cmd["plugin.omp-usage.slack-bad"] == true, "over budget uses the red style", text)
expect(text:find("CLAUDE LOCKED", 1, true) ~= nil, "lockout badge missing at 100%", text)
expect(text:find("Fable", 1, true) ~= nil, "Fable shows when the plan has it", text)
expect(cmd["plugin.omp-usage.pct-crit"] == true, "100% uses the critical style", text)

-- Signed in to Claude only: omp answers Codex with no reports, which hides the group rather than flagging an error.
text = render(claude(0.4, 0, now_ms + 7 * DAY), { reports = {}, capacity = {} })
expect(text:find("Codex", 1, true) == nil, "Codex should hide when omp has no Codex account", text)
expect(text:find("⚠", 1, true) == nil, "a provider without an account is not an error", text)
expect(text:find("✻ Claude", 1, true) ~= nil, "Claude stays when only Codex has no account", text)

-- A read omp couldn't make (rate-limited after a click's invalidate) lists the account without a report: the last
-- reading stays, flagged with ⚠, instead of the group vanishing as if there were no account.
render(claude(0.4, 0, now_ms + 7 * DAY))
text = render({ reports = {}, accountsWithoutUsage = { { provider = "anthropic" } } }, {
	reports = {},
	accountsWithoutUsage = { { provider = "openai-codex" } },
})
expect(text:find("✻ Claude", 1, true) ~= nil, "an unread Claude account keeps the last reading", text)
expect(text:find("40%", 1, true) ~= nil, "the last Claude 5h reading stays", text)
expect(text:find("⬢ Codex", 1, true) ~= nil, "an unread Codex account keeps the last reading", text)
expect(text:find("⚠", 1, true) ~= nil, "a kept reading is flagged as a failed read", text)

-- Settings: each answer is what the palette prompt receives.
local function settle(answer: string, input: string): boolean
	local ok = config.answer[answer](input)
	return ok
end

expect(settle("language", "pt-br"), "language codes match case-insensitively", "")
text = render(claude(0, 0, now_ms + 7 * DAY))
expect(text:find("📅 sobra", 1, true) ~= nil, "pt-BR should show its own words", text)
settle("language", "ja")
text = render(claude(0, 0, now_ms + 7 * DAY))
expect(text:find("📅 残り", 1, true) ~= nil, "ja should show its own words", text)
expect(not settle("language", "klingon"), "an unknown language is refused", "")

-- A reinstall keeps the data folder: loading the store again restores the language.
config.load()
text = render(claude(0, 0, now_ms + 7 * DAY))
expect(text:find("📅 残り", 1, true) ~= nil, "settings should survive a fresh load from tern.kv", text)
settle("language", "en")

settle("part", "Codex")
text = render(claude(0.4, 0, now_ms + 7 * DAY))
expect(text:find("Codex", 1, true) == nil, "a hidden part leaves the bar", text)
expect(text:find("✻ Claude", 1, true) ~= nil, "hiding Codex keeps Claude", text)
settle("part", "codex")
text = render(claude(0.4, 0, now_ms + 7 * DAY))
expect(text:find("⬢ Codex", 1, true) ~= nil, "toggling again shows the part", text)
expect(not settle("part", "weather"), "an unknown part is refused", "")

-- With all 7 days counting, each date the window holds at noon unlocks 1/7. Resets are pinned to a clock time, since
-- whether the window's first date counts depends on it.
local now_t = os.date("*t") :: any
local midnight_ms = (os.time() - now_t.hour * 3600 - now_t.min * 60 - now_t.sec) * 1000
settle("workdays", "7")
-- Opened two days ago at 03:00: that date, yesterday and today, 3/7.
text = render(claude(0, 0, midnight_ms + 5 * DAY + 3 * 3600 * 1000))
expect(text:find("📅 left 43%", 1, true) ~= nil, "a morning reset counts the date the window opened", text)
-- Opened two days ago at 21:00: those three hours belong to the window's last date, so yesterday and today, 2/7.
text = render(claude(0, 0, midnight_ms + 5 * DAY + 21 * 3600 * 1000))
expect(text:find("📅 left 29%", 1, true) ~= nil, "an evening reset leaves the date the window opened out", text)
expect(not settle("workdays", "8"), "more than 7 work days is refused", "")

settle("crit", "60%")
text, cmd = render(claude(0.65, 0, now_ms + 7 * DAY))
expect(cmd["plugin.omp-usage.pct-crit"] == true, "65% is critical with the threshold at 60%", text)
expect(not settle("crit", "20"), "a threshold under 50% is refused", "")

config.reset()
text, cmd = render(claude(0.65, 0, now_ms + 7 * DAY))
expect(cmd["plugin.omp-usage.pct-crit"] == nil, "reset brings the threshold back to 80%", text)
expect(store.settings ~= nil and next(store.settings) == nil, "reset leaves an empty store", "")

-- Alerts: climbing to the threshold, locking and freeing up each toast once; holding a level says nothing.
toasts = {}
render(claude(0.85, 0, now_ms + 7 * DAY))
expect(#toasts == 1 and toasts[1][2] == "Claude 5h at 85%", "climbing to 80% toasts once", toasts[1] and toasts[1][2] or "")
expect(toasts[1][3] == "resets in 1h30m", "the toast says when the window resets", toasts[1][3])
render(claude(0.9, 0, now_ms + 7 * DAY))
expect(#toasts == 1, "staying above the threshold says nothing", "")
render(claude(1, 0, now_ms + 7 * DAY))
expect(toasts[2] and toasts[2][1] == "error" and toasts[2][2] == "Claude 5h is locked", "locking toasts an error", "")
render(claude(0.1, 0, now_ms + 7 * DAY))
expect(toasts[3] and toasts[3][2] == "Claude 5h is free again", "freeing up toasts", "")
settle("part", "alerts")
render(claude(0.85, 0, now_ms + 7 * DAY))
expect(#toasts == 3, "alerts hidden means no toast", "")
settle("part", "alerts")

-- Forecast: at 90% with the reset 90 min away (3.5 h into the 5h window), the average pace runs out in 23 min.
text = render(claude(0.9, 0, now_ms + 7 * DAY))
expect(text:find("⏳23m", 1, true) ~= nil, "the 5h window shows when it runs out", text)
text = render(claude(0.4, 0, now_ms + 7 * DAY))
expect(text:find("⏳", 1, true) == nil, "under 50% there is no forecast", text)
-- Half the week gone in two days runs out in two more, before the reset five days away.
text = render(claude(0.1, 0.5, now_ms + 5 * DAY))
expect(text:find("⏳2d00h", 1, true) ~= nil, "the week shows when it runs out", text)
settle("part", "forecast")
text = render(claude(0.1, 0.5, now_ms + 5 * DAY))
expect(text:find("⏳", 1, true) == nil, "forecast hidden", text)
settle("part", "forecast")

-- Today's total goes to tern.kv under its local date, for the dashboard; days older than 62 are dropped.
local today_key = os.date("%Y-%m-%d") :: string
store.days = { ["2000-01-01"] = { tokens = 1, cost = 1 } }
render(claude(0.1, 0, now_ms + 7 * DAY))
expect(store.days[today_key] and store.days[today_key].cost == 12.4, "today's cost is stored for the dashboard", "")
expect(store.days["2000-01-01"] == nil, "days older than 62 are dropped", "")

print("usage_test: ok")

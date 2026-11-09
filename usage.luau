-- Claude + Codex limits from `omp usage --json` (gradient dots, trend, lockout) and today's tokens from `omp stats`.
local config = require("./config")
local M = {}

local P = "plugin.omp-usage."
local DOTS = 5
local TREND_STEP = 0.03 -- rise between two fetches (5 min) that earns the arrow

local OMP: string = "omp"
local busy = false
local failed = { claude = false, codex = false }
local claude: { [string]: any }? = nil
local codex: { [string]: any }? = nil
local prev: { [string]: number } = {}
local rising: { [string]: boolean } = {}
local today: { tokens: number, cost: number }? = nil
local anim = DOTS

local function num(x: any): number?
	return if type(x) == "number" then x else nil
end

local function mins_until(ms: number?): number?
	return if ms then math.max(0, math.floor((ms / 1000 - os.time()) / 60)) else nil
end

local function hm(mins: number): string
	if mins >= 1440 then
		return string.format("%dd%02dh", mins // 1440, (mins % 1440) // 60)
	end
	return if mins >= 60 then string.format("%dh%02dm", mins // 60, mins % 60) else string.format("%dm", mins)
end

local function track(key: string, f: number?)
	if not f then
		return
	end
	rising[key] = prev[key] ~= nil and f - prev[key] >= TREND_STEP
	prev[key] = f
end

-- Local noon of the date `at` falls on. Luau's os.time(table) reads the table as UTC, so this works from the timestamp.
local function noon_of(at: number): number
	local t = os.date("*t", at) :: any
	return at - t.hour * 3600 - t.min * 60 - t.sec + 12 * 3600
end

-- Work days (from Monday) of the 7d window up to today each unlock 1/workdays; a holiday's share stays banked.
-- A date belongs to the window when the window holds its noon: a window that resets Saturday 21:00 runs Sunday to
-- Saturday, not from the three hours of the Saturday it opened.
local function weekly_slack(used: number?, resets: number?): number?
	if not used or not resets then
		return nil
	end
	local workdays = config.get("workdays")
	local reset = resets / 1000
	local start = reset - 7 * 86400
	local today_key = os.date("%Y%m%d") :: string
	local days = 0
	local noon = noon_of(start)
	for _ = 0, 7 do
		if noon >= reset or (os.date("%Y%m%d", noon) :: string) > today_key then
			break
		end
		local monday_based = ((os.date("*t", noon) :: any).wday + 5) % 7 + 1
		if noon >= start and monday_based <= workdays then
			days += 1
		end
		noon = noon_of(noon + 86400)
	end
	return math.min(1, days / workdays) - used
end

local function slack_segment(out: { any }, used: number?, resets: number?)
	local s = weekly_slack(used, resets)
	if not s then
		return
	end
	local pct = math.floor(math.abs(s) * 100 + 0.5)
	if s >= 0 then
		table.insert(out, { text = string.format("📅 %s %d%%", config.labels.left, pct), command = P .. "slack-ok" })
	else
		table.insert(out, { text = string.format("📅 %s %d%%", config.labels.over, pct), command = P .. "slack-bad" })
	end
end

-- Five steps green → red; dot N always wears step N, the percentage wears the step it reached.
local function bar(out: { any }, label: string, f: number?, key: string)
	table.insert(out, { text = label, tone = "muted", command = P .. "refresh" })
	if not f then
		table.insert(out, { text = "–", tone = "muted", command = P .. "refresh" })
		return
	end
	local filled = math.min(math.clamp(math.floor(f * DOTS + 0.5), 0, DOTS), anim)
	for i = 1, filled do
		table.insert(out, { text = "●", command = P .. "dot-" .. i })
	end
	if filled < DOTS then
		table.insert(out, { text = string.rep("●", DOTS - filled), command = P .. "empty" })
	end
	local pct = string.format("%d%%", math.floor(f * 100 + 0.5)) .. (if rising[key] then "↑" else "")
	local step = math.clamp(math.ceil(f * DOTS), 1, DOTS)
	table.insert(out, { text = pct, command = P .. (if f >= config.get("crit") then "pct-crit" else "pct-" .. step) })
end

local function parse_claude(data): { [string]: any }?
	local report = data.reports and data.reports[1]
	if not report then
		return nil
	end
	local c = {}
	for _, l in report.limits do
		local key = if l.id == "anthropic:5h" then "five" elseif l.id == "anthropic:7d" then "week"
			elseif l.id == "anthropic:7d:fable" then "fable" else nil
		if key then
			c[key] = num(l.amount.usedFraction)
			c[key .. "_reset"] = num(l.window.resetsAt)
		end
	end
	c.credits = if type(report.resetCredits) == "table" then num(report.resetCredits.availableCount) or 0 else 0
	return c
end

local function parse_codex(data): { [string]: any }?
	local reports = data.reports
	if not reports or #reports == 0 then
		return nil
	end
	local x = { credits = 0 }
	for _, cap in (data.capacity and data.capacity["openai-codex"]) or {} do
		local frac = if cap.accounts and cap.accounts > 0 then cap.usedAccounts / cap.accounts else nil
		if cap.window == "5h" then
			x.five = frac
		elseif cap.window == "7d" then
			x.week = frac
		end
		x.n = cap.accounts
	end
	for _, r in reports do
		for _, l in r.limits do
			local key = if l.id == "openai-codex:primary" then "five_reset" elseif l.id == "openai-codex:secondary" then "week_reset" else nil
			local at = key and num(l.window.resetsAt)
			if key and at and (not x[key] or at < x[key]) then
				x[key] = at
			end
		end
		if type(r.resetCredits) == "table" then
			x.credits += num(r.resetCredits.availableCount) or 0
		end
	end
	return x
end

-- Dots fill left to right after each fetch.
local function animate()
	anim = 0
	local function step()
		anim += 1
		tern.chrome.refresh()
		if anim < DOTS then
			tern.timer(90, step)
		end
	end
	tern.timer(90, step)
end

-- 0 calm, 1 at the red-badge threshold, 2 locked.
local levels: { [string]: number } = {}

-- A toast when a window climbs to the threshold, locks, or frees up again. The first reading after a load only
-- records where each window stands, so a reload never repeats an old alert.
local function alert(cx: any, key: string, name: string, window: string, f: number?, reset_ms: number?)
	local new = if not f then 0 elseif f >= 1 then 2 elseif f >= config.get("crit") then 1 else 0
	local old = levels[key]
	levels[key] = new
	if old == nil or new == old or not cx or not config.shows("alerts") then
		return
	end
	local mins = mins_until(reset_ms)
	local sub = if mins then string.format(config.labels.resets_in, hm(mins)) else nil
	local L = config.labels
	if new == 2 then
		cx:toast("error", string.format(L.alert_locked, name, window), sub)
	elseif new == 1 and old == 0 then
		cx:toast("info", string.format(L.alert_hot, name, window, math.floor((f :: number) * 100 + 0.5)), sub)
	elseif old == 2 then
		cx:toast("success", string.format(L.alert_free, name, window))
	end
end

-- tern.process.run raises synchronously when the binary is missing; treat that as a failed fetch.
local function run_json(argv: { string }, done: (any?, any?) -> ())
	local started = pcall(tern.process.run, argv, { timeout_ms = 60000 }, function(res, cx)
		local ok, data = pcall(tern.json.decode, res.stdout)
		done(if res.status == 0 and ok then data else nil, cx)
	end)
	if not started then
		done(nil, nil)
	end
end

function M.fetch(invalidate: boolean?)
	if busy then
		return
	end
	busy = true
	tern.chrome.refresh()
	-- Codex starts once Claude answers, so no callback starts two processes: Tern turns off every timer of a
	-- plugin whose timer callback runs over 50 ms, and on Windows starting a process takes a good part of that.
	local function fetch_codex()
		run_json({ OMP, "usage", "--json", "-p", "openai-codex" }, function(data, cx)
			failed.codex = data == nil
			if data then
				codex = parse_codex(data)
				if codex then
					track("x5", codex.five)
					track("xwk", codex.week)
					alert(cx, "x5", "Codex", "5h", codex.five, codex.five_reset)
					alert(cx, "xwk", "Codex", "wk", codex.week, codex.week_reset)
				end
			end
			busy = false
			animate()
		end)
	end
	local function go()
		-- nil data means omp failed; an answer with no account for the provider hides its group instead.
		run_json({ OMP, "usage", "--json", "-p", "anthropic" }, function(data, cx)
			failed.claude = data == nil
			if data then
				claude = parse_claude(data)
				if claude then
					track("c5", claude.five)
					track("cwk", claude.week)
					alert(cx, "c5", "Claude", "5h", claude.five, claude.five_reset)
					alert(cx, "cwk", "Claude", "wk", claude.week, claude.week_reset)
					alert(cx, "cf", "Claude", "Fable", claude.fable, claude.fable_reset)
				end
			end
			fetch_codex()
		end)
	end
	if not (invalidate and pcall(tern.process.run, { OMP, "usage", "invalidate" }, { timeout_ms = 30000 }, go)) then
		go()
	end
end

local function midnight_ms(): number
	local t = os.date("*t") :: any
	return os.time({ year = t.year, month = t.month, day = t.day, hour = 0, min = 0, sec = 0 }) * 1000
end

-- Keeps each day's total in tern.kv for the dashboard's week and month: `omp stats` only goes back about a day.
local function record_day(tokens: number, cost: number)
	local key = os.date("%Y-%m-%d") :: string
	local ok, days = pcall(tern.kv.get, "days")
	days = if ok and type(days) == "table" then days else {}
	local d = days[key]
	if type(d) == "table" and d.tokens == tokens and d.cost == cost then
		return
	end
	days[key] = { tokens = tokens, cost = cost }
	local oldest = os.date("%Y-%m-%d", os.time() - 62 * 86400) :: string
	for k in days do
		if k < oldest then
			days[k] = nil
		end
	end
	tern.kv.set("days", days)
end

-- Tokens and API-price cost since local midnight, every provider, from `omp stats` hourly buckets.
function M.fetch_today()
	run_json({ OMP, "stats", "--json" }, function(data)
		if not data or not data.timeSeries then
			return
		end
		local since = midnight_ms()
		local tokens, cost = 0, 0
		for _, b in data.timeSeries do
			if (num(b.timestamp) or 0) >= since then
				tokens += num(b.tokens) or 0
				cost += num(b.cost) or 0
			end
		end
		today = { tokens = tokens, cost = cost }
		record_day(tokens, cost)
		tern.chrome.refresh()
	end)
end

local function compact(n: number): string
	return if n >= 1e9 then string.format("%.1fB", n / 1e9) elseif n >= 1e6 then string.format("%.0fM", n / 1e6)
		elseif n >= 1e3 then string.format("%.0fk", n / 1e3) else tostring(n)
end

local function locked(out: { any }, name: string, five: number?, week: number?, r5: number?, rwk: number?, tail: string?)
	if (five or 0) < 1 and (week or 0) < 1 then
		return
	end
	local mins = mins_until(if (week or 0) >= 1 then rwk else r5)
	table.insert(out, {
		text = string.format("%s %s %s%s", name, config.labels.locked, if mins then hm(mins) else "", tail or ""),
		command = P .. "locked",
	})
end

local function credits_tail(n: number): string?
	return if n > 0 and config.shows("credits") then " ✦" .. n else nil
end

-- Minutes until the window runs out at its average pace since it opened, when that comes before its reset.
-- ponytail: linear pace, so a burst early in the window overstates it; nothing shows under 50% used.
local function runs_out(f: number?, reset_ms: number?, span_s: number): number?
	if not f or not reset_ms or f < 0.5 or f >= 1 then
		return nil
	end
	local now = os.time()
	local elapsed = now - (reset_ms / 1000 - span_s)
	if elapsed < 600 then
		return nil
	end
	local left = (1 - f) * elapsed / f
	return if now + left < reset_ms / 1000 then math.floor(left / 60) else nil
end

local function forecast(out: { any }, f: number?, reset_ms: number?, span_s: number)
	local mins = config.shows("forecast") and runs_out(f, reset_ms, span_s)
	if mins then
		table.insert(out, { text = "⏳" .. hm(mins), command = P .. "eta" })
	end
end

function M.segments(out: { any })
	local show_claude, show_codex = config.shows("claude"), config.shows("codex")
	local c = claude
	if c and show_claude then
		locked(out, "CLAUDE", c.five, c.week, c.five_reset, c.week_reset, credits_tail(c.credits))
		table.insert(out, { text = "✻ Claude", command = P .. "claude" })
		bar(out, "5h", c.five, "c5")
		forecast(out, c.five, c.five_reset, 5 * 3600)
		bar(out, "wk", c.week, "cwk")
		forecast(out, c.week, c.week_reset, 7 * 86400)
		if c.fable and config.shows("fable") then
			bar(out, "Fable", c.fable, "cf")
		end
		local mins = mins_until(c.five_reset)
		if mins and config.shows("reset") then
			local soon = (c.five or 0) >= config.get("crit") and mins < 30
			table.insert(out, {
				text = config.labels.reset .. " " .. hm(mins),
				command = if soon then P .. "reset-soon" else P .. "reset",
			})
		end
		if c.credits > 0 and config.shows("credits") then
			table.insert(out, { text = "✦" .. c.credits, command = P .. "credits" })
		end
		if config.shows("budget") then
			slack_segment(out, c.week, c.week_reset)
		end
	elseif failed.claude and show_claude then
		table.insert(out, { text = "✻ Claude ?", tone = "error", command = P .. "refresh" })
	end

	local x = codex
	if x and show_codex then
		locked(out, "CODEX", x.five, x.week, x.five_reset, x.week_reset, credits_tail(x.credits))
		table.insert(out, { text = "⬢ Codex", command = P .. "codex" })
		bar(out, "5h", x.five, "x5")
		bar(out, "wk", x.week, "xwk")
		if x.n then
			table.insert(out, { text = "×" .. x.n, tone = "muted", command = P .. "refresh" })
		end
		if x.credits > 0 and config.shows("credits") then
			table.insert(out, { text = "✦" .. x.credits, command = P .. "credits" })
		end
	elseif failed.codex and show_codex then
		table.insert(out, { text = "⬢ Codex ?", tone = "error", command = P .. "refresh" })
	end

	if today and config.shows("today") then
		table.insert(out, { text = "🔥 " .. compact(today.tokens) .. " " .. config.labels.tokens, command = P .. "today" })
	end
	if today and config.shows("cost") then
		table.insert(out, { text = string.format("💸 $%.0f", today.cost), command = P .. "cost" })
	end
	if (failed.claude and show_claude) or (failed.codex and show_codex) then
		table.insert(out, { text = "⚠", tone = "error", command = P .. "refresh" })
	end
	table.insert(out, if busy then { text = "⟳ …", tone = "muted" } else { text = "⟳", tone = "accent", command = P .. "refresh" })
end

-- Clicking a segment refreshes; `today` and `cost` open the dashboard instead (window.luau).
function M.init(omp: string, hidden: (string, (any) -> ()) -> ())
	OMP = omp
	for _, id in { "claude", "codex", "credits", "dot-1", "dot-2", "dot-3", "dot-4", "dot-5",
		"pct-1", "pct-2", "pct-3", "pct-4", "pct-5", "pct-crit", "empty", "locked", "reset", "reset-soon", "slack-ok", "slack-bad",
		"eta" } do
		hidden(id, function()
			M.fetch(true)
		end)
	end
end

return M

-- Claude and Codex limits from `omp usage --json` (share used, trend, lock, forecast, the work-week budget, saved
-- resets, logins omp turned off) and today's tokens, cost and speed from `omp stats`, as widgets for Tern's widget
-- bar (tern.chrome.widget): people place the ones they want with palette › Edit widgets….
local config = require("./config")
local history = require("./history")
local M = {}

local P = "plugin.omp-usage."
local REFRESH, DASHBOARD = P .. "refresh", P .. "dashboard"
local TREND_STEP = 0.03 -- rise between two fetches (5 min) that earns the arrow
local EXPIRING_S = 2 * 86400 -- a usable saved reset this close to expiring gets one toast
local SHORT = {
	["anthropic:5h"] = "5h",
	["anthropic:7d"] = "wk",
	["anthropic:7d:fable"] = "Fable",
	["openai-codex:primary"] = "5h",
	["openai-codex:secondary"] = "wk",
}

local OMP: string = "omp"
local busy = false
local failed = { claude = false, codex = false }
local claude: { [string]: any }? = nil
local codex: { [string]: any }? = nil
local disabled: { { provider: string, cause: string } } = {} -- logins omp turned off, from the last round
local today: { [string]: any }? = nil
local perf: { [string]: number }? = nil
local prev: { [string]: number } = {}
local rising: { [string]: boolean } = {}

local function num(x: any): number?
	return if type(x) == "number" then x else nil
end

local function pct(f: number): number
	return math.floor(f * 100 + 0.5)
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

local function compact(n: number): string
	return if n >= 1e9 then string.format("%.1fB", n / 1e9) elseif n >= 1e6 then string.format("%.0fM", n / 1e6)
		elseif n >= 1e3 then string.format("%.0fk", n / 1e3) else tostring(n)
end

local function money(n: number): string
	return string.format("$%.0f", n)
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
local function budget(used: number?, resets: number?): { slack: number, allowed: number, days: number }?
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
	local allowed = math.min(1, days / workdays)
	return { slack = allowed - used, allowed = allowed, days = days }
end

-- Minutes until the window is used up at its average pace since it opened; nil in its first 10 minutes, at 0% or full.
-- ponytail: linear pace, so a burst early in the window overstates it.
local function pace_left(f: number?, reset_ms: number?, span_s: number): number?
	if not f or not reset_ms or f <= 0 or f >= 1 then
		return nil
	end
	local elapsed = os.time() - (reset_ms / 1000 - span_s)
	if elapsed < 600 then
		return nil
	end
	return math.floor((1 - f) * elapsed / f / 60)
end

-- The forecast widget's minutes: when the window runs out at that pace before its reset; nothing under 50% used.
local function runs_out(f: number?, reset_ms: number?, span_s: number): number?
	if not f or f < 0.5 then
		return nil
	end
	local left, mins = pace_left(f, reset_ms, span_s), mins_until(reset_ms)
	return if left and mins and left < mins then left else nil
end

-- "2026-12-10T22:00:00.000Z" → epoch seconds; Luau's os.time reads a table as UTC.
local function expiry(iso: string?): number?
	local y, mo, d, h, mi, s = string.match(iso or "", "^(%d+)-(%d+)-(%d+)T(%d+):(%d+):(%d+)")
	if not y then
		return nil
	end
	return os.time({ year = tonumber(y), month = tonumber(mo), day = tonumber(d), hour = tonumber(h), min = tonumber(mi), sec = tonumber(s) } :: any)
end

-- `resetCredits` of one report: saved, usable now (omp before `redeemableCount` counted every saved one as usable),
-- and each credit's state, the windows it clears and when it expires.
local function read_credits(rc: any, into: { [string]: any })
	if type(rc) ~= "table" then
		return
	end
	local saved = num(rc.availableCount) or 0
	into.saved += saved
	into.usable += num(rc.redeemableCount) or saved
	for _, c in (if type(rc.credits) == "table" then rc.credits else {}) do
		if type(c) == "table" and (c.status == "available" or c.status == "unavailable") then
			table.insert(into.list, {
				id = if type(c.id) == "string" then c.id else nil,
				usable = c.usable == true or (c.usable == nil and c.status == "available"),
				clears = if type(c.clears) == "table" then c.clears else {},
				expires = if type(c.expiresAt) == "string" then c.expiresAt else nil,
			})
		end
	end
end

local function no_credits(): { [string]: any }
	return { saved = 0, usable = 0, list = {} }
end

local function parse_claude(data): { [string]: any }?
	local report = data.reports and data.reports[1]
	if not report then
		return nil
	end
	local c: { [string]: any } = { credits = no_credits() }
	for _, l in report.limits do
		local key = if l.id == "anthropic:5h" then "five" elseif l.id == "anthropic:7d" then "week"
			elseif l.id == "anthropic:7d:fable" then "fable" else nil
		if key then
			c[key] = num(l.amount.usedFraction)
			c[key .. "_reset"] = num(l.window.resetsAt)
		end
	end
	read_credits(report.resetCredits, c.credits)
	return c
end

local function parse_codex(data): { [string]: any }?
	local reports = data.reports
	if not reports or #reports == 0 then
		return nil
	end
	local x: { [string]: any } = { credits = no_credits() }
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
		read_credits(r.resetCredits, x.credits)
	end
	return x
end

-- Logins omp turned off; each reply lists them, so a round keeps one of each. The cause is cut short and loses
-- anything shaped like an e-mail address.
local function read_disabled(data: any, into: { { provider: string, cause: string } })
	for _, d in (if type(data.disabledCredentials) == "table" then data.disabledCredentials else {}) do
		if type(d) == "table" and type(d.provider) == "string" then
			local cause = string.gsub(if type(d.cause) == "string" then d.cause else "", "[%w._%%+-]+@[%w.-]+", "…")
			local cut = utf8.offset(cause, 121)
			if cut and cut <= #cause then
				cause = string.sub(cause, 1, cut - 1) .. "…"
			end
			local dup = false
			for _, x in into do
				dup = dup or (x.provider == d.provider and x.cause == cause)
			end
			if not dup then
				table.insert(into, { provider = d.provider, cause = cause })
			end
		end
	end
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
		cx:toast("info", string.format(L.alert_hot, name, window, pct(f :: number)), sub)
	elseif old == 2 then
		cx:toast("success", string.format(L.alert_free, name, window))
	end
end

local usable_seen: { [string]: number } = {}

-- A toast when a provider's usable resets go up (the first reading after a load only records the count), and one
-- per credit, kept across restarts in tern.kv, when a usable one gets close to expiring.
local function credit_alerts(cx: any, name: string, credits: { [string]: any })
	local old = usable_seen[name]
	usable_seen[name] = credits.usable
	if not cx or not config.shows("alerts") then
		return
	end
	local L = config.labels
	if old ~= nil and credits.usable > old then
		cx:toast("success", string.format(L.alert_reset_usable, name, credits.usable))
	end
	for _, c in credits.list do
		local at = c.usable and c.id and expiry(c.expires)
		if at and at - os.time() < EXPIRING_S then
			local ok, saved = pcall(tern.kv.get, "expiring")
			local warned = if ok and type(saved) == "table" then saved else {}
			if not warned[c.id] then
				warned[c.id] = true
				tern.kv.set("expiring", warned)
				cx:toast("info", string.format(L.alert_reset_expiring, name, os.date("%d/%m %H:%M", at)))
			end
		end
	end
end

local known_off: { [string]: boolean }? = nil

-- A toast for each login omp turns off; the first round after a load only records the ones already off.
local function login_alerts(cx: any, found: { { provider: string, cause: string } })
	local first = known_off == nil
	local now: { [string]: boolean } = {}
	for _, d in found do
		local key = d.provider .. "\n" .. d.cause
		now[key] = true
		if not first and not (known_off :: any)[key] and cx and config.shows("alerts") then
			cx:toast("error", string.format(config.labels.login_off, history.name(d.provider)), if d.cause ~= "" then d.cause else nil)
		end
	end
	known_off = now
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

-- omp answers an account it couldn't read this time with no report and the account under accountsWithoutUsage:
-- Anthropic refuses reads under ~5 min apart, and a click invalidates omp's cache. That is a failed read, which keeps
-- the last reading; only an answer without the account hides the group.
local function unread(data: any, provider: string): boolean
	if type(data.reports) == "table" and #data.reports > 0 then
		return false
	end
	for _, a in data.accountsWithoutUsage or {} do
		if a.provider == provider then
			return true
		end
	end
	return false
end

function M.fetch(invalidate: boolean?)
	if busy then
		return
	end
	busy = true
	local found: { { provider: string, cause: string } } = {}
	-- Codex starts once Claude answers, so no callback starts two processes: Tern turns off every timer of a
	-- plugin whose timer callback runs over 50 ms, and on Windows starting a process takes a good part of that.
	local function fetch_codex()
		run_json({ OMP, "usage", "--json", "-p", "openai-codex" }, function(data, cx)
			if data then
				read_disabled(data, found)
				if unread(data, "openai-codex") then
					data = nil
				end
			end
			failed.codex = data == nil
			if data then
				codex = parse_codex(data)
				if codex then
					track("x5", codex.five)
					track("xwk", codex.week)
					alert(cx, "x5", "Codex", "5h", codex.five, codex.five_reset)
					alert(cx, "xwk", "Codex", "wk", codex.week, codex.week_reset)
					credit_alerts(cx, "Codex", codex.credits)
				end
			end
			disabled = found
			login_alerts(cx, found)
			busy = false
			M.paint()
		end)
	end
	local function go()
		-- nil data means omp failed; an answer with no account for the provider hides its widgets instead.
		run_json({ OMP, "usage", "--json", "-p", "anthropic" }, function(data, cx)
			if data then
				read_disabled(data, found)
				if unread(data, "anthropic") then
					data = nil
				end
			end
			failed.claude = data == nil
			if data then
				claude = parse_claude(data)
				if claude then
					track("c5", claude.five)
					track("cwk", claude.week)
					alert(cx, "c5", "Claude", "5h", claude.five, claude.five_reset)
					alert(cx, "cwk", "Claude", "wk", claude.week, claude.week_reset)
					alert(cx, "cf", "Claude", "Fable", claude.fable, claude.fable_reset)
					credit_alerts(cx, "Claude", claude.credits)
				end
			end
			fetch_codex()
		end)
	end
	if not (invalidate and pcall(tern.process.run, { OMP, "usage", "invalidate" }, { timeout_ms = 30000 }, go)) then
		go()
	end
end

-- The last local midnight in epoch seconds. Not os.time() of today's date at 00:00: Luau reads that table as UTC,
-- which starts "today" hours early or late away from UTC.
local function midnight(): number
	local now = os.time()
	local t = os.date("*t", now) :: any
	return now - (t.hour * 3600 + t.min * 60 + t.sec)
end

-- Keeps each day's total in tern.kv for the dashboard's week and month (`omp stats` only goes back about a day);
-- returns every day kept.
local function record_day(tokens: number, cost: number): { [string]: any }
	local key = os.date("%Y-%m-%d") :: string
	local ok, days = pcall(tern.kv.get, "days")
	days = if ok and type(days) == "table" then days else {}
	local d = days[key]
	if type(d) == "table" and d.tokens == tokens and d.cost == cost then
		return days
	end
	days[key] = { tokens = tokens, cost = cost }
	local oldest = os.date("%Y-%m-%d", os.time() - 62 * 86400) :: string
	for k in days do
		if k < oldest then
			days[k] = nil
		end
	end
	tern.kv.set("days", days)
	return days
end

-- shortcut: Tern draws about one sample per pixel, right-aligned, in a graph about 42 px wide, and omp's stats come
-- by the hour; each hour repeats until the day spans 48 samples. Upgrade if omp ever gives finer buckets.
local GRAPH_SAMPLES = 48

-- The running total since midnight, 0–1 of the day's total, for the widgets' graph style: its end is the number the
-- widget shows.
local function running(xs: { number }): { number }
	local per = math.max(1, math.ceil(GRAPH_SAMPLES / math.max(1, #xs)))
	local total = 0
	for _, x in xs do
		total += x
	end
	local out, sum = {}, 0
	for _, x in xs do
		sum += x
		for _ = 1, per do
			table.insert(out, if total > 0 then sum / total else 0)
		end
	end
	return out
end

-- Tokens, requests and API-price cost since local midnight, hour by hour and every provider, and the speed and
-- cache rate of omp's last day, from `omp stats`.
function M.fetch_today()
	run_json({ OMP, "stats", "--json" }, function(data)
		if not data or not data.timeSeries then
			return
		end
		local since = midnight() * 1000
		local hours = (os.time() * 1000 - since) // 3600000 + 1
		local t = { tokens = 0, cost = 0, requests = 0, by_hour = {}, cost_by_hour = {} }
		for i = 1, hours do
			t.by_hour[i], t.cost_by_hour[i] = 0, 0
		end
		for _, b in data.timeSeries do
			local at = num(b.timestamp) or 0
			local i = (at - since) // 3600000 + 1
			if at >= since and i <= hours then
				local tokens, cost = num(b.tokens) or 0, num(b.cost) or 0
				t.tokens += tokens
				t.cost += cost
				t.requests += num(b.requests) or 0
				t.by_hour[i] += tokens
				t.cost_by_hour[i] += cost
			end
		end
		local now = os.time()
		local days = record_day(t.tokens, t.cost)
		local c = history.costs(days, now)
		today = {
			tokens = t.tokens,
			cost = t.cost,
			requests = t.requests,
			week = c.week,
			month = c.month,
			since_monday = history.week_tokens(days, now),
			tokens_series = running(t.by_hour),
			cost_series = running(t.cost_by_hour),
		}
		local o = data.overall
		perf = if type(o) == "table" and num(o.avgTokensPerSecond)
			then {
				tps = o.avgTokensPerSecond,
				ttft = (num(o.avgTtft) or 0) / 1000,
				cache = num(o.cacheRate) or 0,
				savings = num(o.cacheSavings) or 0,
				since = (num(o.firstTimestamp) or 0) // 1000,
			}
			else nil
		tern.chrome.refresh()
	end)
end

-- What a widget shows; `value` fills the bar or ring styles, `series` the graph style (0–1 each).
type View = { text: string, tone: string?, title: string?, command: string?, icon: string?, value: number?, series: { number }? }

-- The limit widgets look like the old status line: five dots, dot N in step N from green to red once reached, and
-- the percentage in the step it reached, red from the red-badge threshold on; the provider's icon in its color, on
-- the 5h widget only, so wk and Fable placed beside it don't repeat it.
local DOTS = 5
local STEP = { "#22c55e", "#a3e635", "#facc15", "#f97316", "#ef4444" }
local DIM, LABEL, RED = "color-mix(in srgb, var(--t1) 16%, transparent)", "var(--t3)", "#ef4444"
local PROVIDER = {
	claude = { name = "Claude", icon = "provider-anthropic", color = "#d97757" },
	codex = { name = "Codex", icon = "provider-openai-codex", color = "#3b82f6" },
}
local LIMITS = {
	{ id = "claude-5h", provider = "claude", window = "5h", field = "five", key = "c5", span_s = 5 * 3600 },
	{ id = "claude-week", provider = "claude", window = "wk", field = "week", key = "cwk", span_s = 7 * 86400 },
	{ id = "claude-fable", provider = "claude", window = "Fable", field = "fable", key = "cf", span_s = 7 * 86400 },
	{ id = "codex-5h", provider = "codex", window = "5h", field = "five", key = "x5" },
	{ id = "codex-week", provider = "codex", window = "wk", field = "week", key = "xwk" },
}

-- "5h ●●●●● 46%" and the CSS that colors it: one text, so one gradient clipped to it with hard stops where the
-- characters meet. The widget bar's font is monospace and every character here takes one cell.
local function dots(id: string, window: string, f: number, up: boolean): (string, string)
	local filled = math.clamp(math.ceil(f * DOTS), 0, DOTS)
	local share = string.format("%d%%", pct(f)) .. (if up then "↑" else "")
	local runs = { { utf8.len(window) :: number + 1, LABEL } }
	for i = 1, DOTS do
		table.insert(runs, { 1, if i <= filled then STEP[i] else DIM })
	end
	table.insert(runs, { 1 + utf8.len(share) :: number, if f >= config.get("crit") then RED else STEP[math.max(filled, 1)] })
	local text = window .. " " .. string.rep("●", DOTS) .. " " .. share
	local total = utf8.len(text) :: number
	local stops, at = {}, 0
	for _, r in runs do
		table.insert(stops, string.format("%s %.3f%%, %s %.3f%%", r[2], at * 100 / total, r[2], (at + r[1]) * 100 / total))
		at += r[1]
	end
	return text,
		string.format(
			"#widgetbar .wg[data-widget='omp-usage/%s'] .wg-v { background-image: linear-gradient(90deg, %s); "
				.. "-webkit-background-clip: text; background-clip: text; color: transparent; }",
			id,
			table.concat(stops, ", ")
		)
end

-- A hover card: Tern draws each `Key: value` line of a widget's title as a row, the value right-aligned in mono, and
-- any other line as text cut with an ellipsis. The card is about 270 px wide inside, so keys and values stay short;
-- usage_test checks every card fits, in every language.
local function card(rows: { any }): string
	local lines = {}
	for _, r in rows do
		table.insert(lines, if type(r) == "table" then r[1] .. ": " .. r[2] else r)
	end
	return table.concat(lines, "\n")
end

-- One limit widget and the CSS rule that paints it: the dots, ↑ when rising, LOCKED and the time to its reset at
-- 100%, '?' when omp failed. Its card: share used, reset, and with a window span the pace since it opened, against
-- the reset.
local function limit_view(l: { [string]: any }): (View?, string?)
	local L = config.labels
	local who = PROVIDER[l.provider]
	local icon = if l.window == "5h" then who.icon else nil
	local p = if l.provider == "claude" then claude else codex
	if not p then
		if failed[l.provider] and l.field ~= "fable" then
			return { text = l.window .. " ?", tone = "error", icon = icon, title = card({ { who.name, L.failed }, L.click_retry }), command = REFRESH }, nil
		end
		return nil, nil
	end
	local f, reset_ms = p[l.field], p[l.field .. "_reset"]
	if f == nil then
		return nil, nil
	end
	local mins = mins_until(reset_ms)
	local rows: { any } = { { L.k_used, pct(f) .. "%" } }
	if mins then
		table.insert(rows, { if f >= 1 then L.k_frees else L.k_resets, hm(mins) })
	end
	local left = l.span_s and pace_left(f, reset_ms, l.span_s)
	if left then
		table.insert(rows, { L.k_pace, hm(left) })
		if mins then
			table.insert(rows, if left < mins then string.format(L.pace_bad, hm(mins - left)) else L.pace_ok)
		end
	end
	if rising[l.key] then
		table.insert(rows, L.tip_rising)
	end
	if l.provider == "codex" and p.n then
		table.insert(rows, { L.k_accounts, tostring(p.n) })
	end
	local view: View = { text = "", icon = icon, title = card(rows), command = REFRESH }
	if f >= 1 then
		view.text = string.format("%s %s%s", l.window, L.locked, if mins then " " .. hm(mins) else "")
		view.tone = "error"
		return view, nil
	end
	local text, rule = dots(l.id, l.window, f, rising[l.key] == true)
	view.text = text
	return view, rule
end

-- The limit widgets' views and their style sheet, built together so each text and its colors match. Runs after a
-- fetch and on the minute tick (the countdown, a new language or threshold); renders only read `limit_views`.
local limit_views: { [string]: View } = {}
local sheet = ""

function M.paint()
	local rules = {}
	for name, who in PROVIDER do
		table.insert(rules, string.format("#widgetbar .wg[data-widget^='omp-usage/%s-'] .wg-ico { color: %s; }", name, who.color))
	end
	for _, l in LIMITS do
		local view, rule = limit_view(l)
		limit_views[l.id] = view :: any
		if rule then
			table.insert(rules, rule)
		end
	end
	table.sort(rules)
	local next_sheet = table.concat(rules, "\n")
	if next_sheet ~= sheet then
		sheet = next_sheet
		tern.css("dots", sheet)
	end
	tern.chrome.refresh()
end

local function windows(ids: { any }): string
	local names = {}
	for _, id in ids do
		table.insert(names, SHORT[id] or tostring(id))
	end
	return table.concat(names, ", ")
end

type Spec = { id: string, name: string, desc: string, styles: { string }, render: (any) -> View? }

local function limit_spec(l: { [string]: any }): Spec
	local name = PROVIDER[l.provider].name
	return {
		id = l.id,
		name = name .. " " .. l.window,
		desc = string.format(config.labels.w_limit_desc, name, l.window),
		styles = { "text" },
		render = function()
			return limit_views[l.id]
		end,
	}
end

local function specs(): { Spec }
	local L = config.labels
	return {
		{
			id = "budget",
			name = L.w_budget,
			desc = L.w_budget_desc,
			styles = { "text", "bar" },
			render = function()
				local c = claude
				local b = c and budget(c.week, c.week_reset)
				if not c or not b then
					return nil
				end
				local L2 = config.labels
				return {
					text = string.format("📅 %s %d%%", if b.slack >= 0 then L2.left else L2.over, pct(math.abs(b.slack))),
					value = if b.allowed > 0 then math.clamp(c.week / b.allowed, 0, 1) else 1,
					tone = if b.slack >= 0 then "ok" else "error",
					title = card({
						{ L2.k_week_used, pct(c.week) .. "%" },
						{ L2.k_unlocked, pct(b.allowed) .. "%" },
						{ L2.k_workdays, string.format(L2.k_of, b.days, config.get("workdays")) },
					}),
					command = DASHBOARD,
				}
			end,
		},
		{
			id = "forecast",
			name = L.w_forecast,
			desc = L.w_forecast_desc,
			styles = { "text" },
			render = function()
				local c = claude
				if not c then
					return nil
				end
				local window, mins, reset = nil, nil, nil
				for _, w in { { "5h", c.five, c.five_reset, 5 * 3600 }, { "wk", c.week, c.week_reset, 7 * 86400 } } do
					local m = runs_out(w[2], w[3], w[4])
					if m and (not mins or m < mins) then
						window, mins, reset = w[1], m, w[3]
					end
				end
				if not mins then
					return nil
				end
				local L2 = config.labels
				local left = mins_until(reset)
				local rows: { any } = { { L2.k_window, "Claude " .. window }, { L2.k_runs_out, hm(mins) } }
				if left then
					table.insert(rows, { L2.k_resets, hm(left) })
				end
				return {
					text = "⏳ " .. window .. " " .. hm(mins),
					tone = "warn",
					title = card(rows),
					command = REFRESH,
				}
			end,
		},
		{
			id = "resets",
			name = L.w_resets,
			desc = L.w_resets_desc,
			styles = { "text" },
			render = function()
				local L2 = config.labels
				local saved, usable, tip = 0, 0, {}
				for _, pair in { { "Claude", claude }, { "Codex", codex } } do
					local p = pair[2]
					if p then
						saved += p.credits.saved
						usable += p.credits.usable
						for _, c in p.credits.list do
							local state = if c.usable then L2.now_short else L2.later_short
							local expires = if c.expires then string.sub(c.expires, 1, 10) else "?"
							table.insert(tip, { pair[1] .. " " .. windows(c.clears), state .. " · " .. expires })
						end
					end
				end
				if saved == 0 then
					return nil
				end
				return {
					text = if usable == saved then "✦ " .. saved else string.format("✦ %d/%d", usable, saved),
					tone = if usable > 0 then "accent" else "muted",
					title = card(tip),
					command = REFRESH,
				}
			end,
		},
		{
			id = "today",
			name = L.w_today,
			desc = L.w_today_desc,
			styles = { "text", "graph" },
			render = function()
				local t = today
				if not t then
					return nil
				end
				return {
					text = "🔥 " .. compact(t.tokens),
					series = t.tokens_series,
					title = card({
						{ config.labels.dash_today, compact(t.tokens) .. " " .. config.labels.tokens },
						{ config.labels.k_since_monday, compact(t.since_monday) .. " " .. config.labels.tokens },
						{ config.labels.k_requests, tostring(t.requests) },
					}),
					command = DASHBOARD,
				}
			end,
		},
		{
			id = "cost",
			name = L.w_cost,
			desc = L.w_cost_desc,
			styles = { "text", "graph" },
			render = function()
				local t = today
				if not t then
					return nil
				end
				return {
					text = "💸 " .. money(t.cost),
					series = t.cost_series,
					title = card({
						{ config.labels.dash_today, money(t.cost) },
						{ config.labels.dash_week, money(t.week) },
						{ config.labels.dash_month, money(t.month) },
						config.labels.dash_cost,
					}),
					command = DASHBOARD,
				}
			end,
		},
		{
			id = "speed",
			name = L.w_speed,
			desc = L.w_speed_desc,
			styles = { "text", "ring" },
			render = function()
				local s = perf
				if not s then
					return nil
				end
				local tps = math.floor(s.tps + 0.5)
				return {
					text = string.format("⚡ %d tok/s · ♻ %d%%", tps, pct(s.cache)),
					value = s.cache,
					title = card({
						{ config.labels.k_speed, tps .. " tok/s" },
						{ config.labels.k_first_token, string.format("%.1f s", s.ttft) },
						{ config.labels.k_cache, pct(s.cache) .. "%" },
						{ config.labels.k_saved, pct(s.savings) .. "%" },
						{ config.labels.k_since, os.date("%d/%m %H:%M", s.since) :: string },
					}),
					command = DASHBOARD,
				}
			end,
		},
		{
			id = "health",
			name = L.w_health,
			desc = L.w_health_desc,
			styles = { "text" },
			render = function()
				local L2 = config.labels
				local rows, n, short = {}, 0, nil
				for _, d in disabled do
					local name = history.name(d.provider)
					short = short or (name .. " " .. L2.off)
					n += 1
					table.insert(rows, { name, L2.k_login })
					if d.cause ~= "" then
						-- One text line: omp's cause can carry the provider's JSON body over several lines, and a colon
						-- would turn it into a key and a value.
						table.insert(rows, (string.gsub(string.gsub(d.cause, "%s+", " "), ":%s", " · ")))
					end
				end
				for _, pair in { { "Claude", failed.claude }, { "Codex", failed.codex } } do
					if pair[2] then
						short = short or "omp ?"
						n += 1
						table.insert(rows, { pair[1], L2.failed })
					end
				end
				if not short then
					return nil
				end
				table.insert(rows, L2.click_retry)
				return {
					text = "⚠ " .. short .. (if n > 1 then " +" .. (n - 1) else ""),
					tone = "error",
					title = card(rows),
					command = REFRESH,
				}
			end,
		},
	}
end

-- Offers every widget to the widget bar; registering an id again replaces it in place, so a language change calls
-- this again for the gallery's names. Each render only reads what the fetches cached: Tern gives it 4 ms.
function M.widgets()
	local all = specs()
	for i, l in LIMITS do
		table.insert(all, i, limit_spec(l))
	end
	for _, s in all do
		tern.chrome.widget(s.id, { name = s.name, description = s.desc, styles = s.styles, render = s.render })
	end
end

function M.init(omp: string)
	OMP = omp
end

return M

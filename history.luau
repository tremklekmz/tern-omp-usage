-- Dashboard data: hourly usage series from `omp usage --history --json` and cost totals from the days the
-- window half records in tern.kv. No tern calls, so tests/history_test.luau runs it directly.
local M = {}

-- omp's provider ids as people know them.
local NAMES = {
	anthropic = "Claude",
	["openai-codex"] = "Codex",
	["google-antigravity"] = "Gemini",
	["xai-oauth"] = "xAI",
	["opencode-go"] = "OpenCode Go",
}

function M.name(provider: string): string
	return NAMES[provider] or provider
end

-- Short names for the windows the plugin has always shown, in this order; any other limit shows omp's label.
local SHORT = {
	{ "anthropic:5h", "5h" },
	{ "anthropic:7d", "wk" },
	{ "anthropic:7d:fable", "Fable" },
	{ "openai-codex:primary", "5h" },
	{ "openai-codex:secondary", "wk" },
}
local RANK = { anthropic = 1, ["openai-codex"] = 2 }

-- The providers in the history with their limits: Claude, Codex, then the rest by name, each limit as
-- `{ id, label }`. A label two limits of one provider share (Gemini's 5h and weekly) gets omp's window name; a
-- label and window seen already (Antigravity reports its shared Claude & GPT quota once per model family) is left out.
function M.groups(entries: { any }): { { name: string, limits: { { id: string, label: string } } } }
	local providers: { [string]: { ids: { string }, label: { [string]: string }, window: { [string]: string } } } = {}
	for _, e in entries do
		local id = e.limitId
		local provider = if type(e.provider) == "string" then e.provider elseif type(id) == "string" then string.match(id, "^([^:]+):") else nil
		if type(id) == "string" and provider then
			local p = providers[provider] or { ids = {}, label = {}, window = {} }
			providers[provider] = p
			if not p.label[id] then
				table.insert(p.ids, id)
				p.label[id] = if type(e.label) == "string" then e.label else id
				p.window[id] = if type(e.windowLabel) == "string" then e.windowLabel else ""
			end
		end
	end
	local order: { string } = {}
	for provider in providers do
		table.insert(order, provider)
	end
	table.sort(order, function(a, b)
		local ra, rb = RANK[a] or 99, RANK[b] or 99
		return if ra ~= rb then ra < rb else M.name(a) < M.name(b)
	end)
	local out = {}
	for _, provider in order do
		local p = providers[provider]
		local limits = {}
		for _, pair in SHORT do
			if p.label[pair[1]] then
				table.insert(limits, { id = pair[1], label = pair[2] })
			end
		end
		local uses: { [string]: number } = {}
		for _, id in p.ids do
			uses[p.label[id]] = (uses[p.label[id]] or 0) + 1
		end
		local seen: { [string]: boolean } = {}
		for _, id in p.ids do
			local known = false
			for _, pair in SHORT do
				known = known or pair[1] == id
			end
			local label = p.label[id]
			label = if uses[label] > 1 and p.window[id] ~= "" then label .. " · " .. p.window[id] else label
			if not known and not seen[label] then
				seen[label] = true
				table.insert(limits, { id = id, label = label })
			end
		end
		table.insert(out, { name = M.name(provider), limits = limits })
	end
	return out
end

-- Per limit id, `{ hour start (epoch s), used fraction }` oldest first. Accounts of one limit in the same hour
-- are averaged. Only limitId, usedFraction and recordedAt are read: entries also carry emails and account ids.
function M.series(entries: { any }): { [string]: { { number } } }
	local sums: { [string]: { [number]: { number } } } = {}
	for _, e in entries do
		local f, at = e.usedFraction, e.recordedAt
		if type(e.limitId) == "string" and type(f) == "number" and type(at) == "number" then
			local hour = at // 3600000
			local by_hour = sums[e.limitId] or {}
			sums[e.limitId] = by_hour
			local s = by_hour[hour] or { 0, 0 }
			by_hour[hour] = s
			s[1] += f
			s[2] += 1
		end
	end
	local out: { [string]: { { number } } } = {}
	for id, by_hour in sums do
		local hours: { number } = {}
		for h in by_hour do
			table.insert(hours, h)
		end
		table.sort(hours)
		local points: { { number } } = {}
		for _, h in hours do
			table.insert(points, { h * 3600, by_hour[h][1] / by_hour[h][2] })
		end
		out[id] = points
	end
	return out
end

local function cost_of(d: any): number
	return if type(d) == "table" and type(d.cost) == "number" then d.cost else 0
end

-- Cost today, over the last 7 days (today included) and this calendar month, plus the last 7 days oldest first
-- as `{ "MM-DD", cost }`. `days` maps "YYYY-MM-DD" (local) to `{ tokens, cost }`.
function M.costs(days: { [string]: any }, now: number): { today: number, week: number, month: number, last7: { { any } } }
	local month = os.date("%Y-%m", now) :: string
	local r = { today = 0, week = 0, month = 0, last7 = {} }
	for key, d in days do
		if string.sub(key, 1, 7) == month then
			r.month += cost_of(d)
		end
	end
	for i = 6, 0, -1 do
		local t = now - i * 86400
		local cost = cost_of(days[os.date("%Y-%m-%d", t) :: string])
		r.week += cost
		table.insert(r.last7, { os.date("%m-%d", t), cost })
		if i == 0 then
			r.today = cost
		end
	end
	return r
end

-- Tokens since Monday (local), today included, from the same `days`.
function M.week_tokens(days: { [string]: any }, now: number): number
	local since_monday = ((os.date("*t", now) :: any).wday + 5) % 7 -- Monday 0 … Sunday 6
	local total = 0
	for i = 0, since_monday do
		local d = days[os.date("%Y-%m-%d", now - i * 86400) :: string]
		total += if type(d) == "table" and type(d.tokens) == "number" then d.tokens else 0
	end
	return total
end

return M

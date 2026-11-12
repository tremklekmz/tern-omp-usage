-- Host half: the dashboard block. 7 days of every provider's limits from `omp usage --history`, the API-price cost of
-- today, the last 7 days and this month, and the cost by model from `omp stats`. Opened by OMP usage: dashboard or a
-- click on the tokens, cost, budget or speed widget.
local config = require("./config")
local history = require("./history")
local ui = tern.ui
local OMP = config.omp_bin()

type Model = { name: string, cost: number, requests: number, cache: number, tps: number }

type State = {
	cx: BlockCx,
	series: { [string]: { { number } } }?,
	groups: { any }?,
	models: { since: number, rows: { Model } }?,
	days: { [string]: any },
	failed: boolean,
	loading: boolean,
	fetched: number?,
}

-- A pane id survives Restart, so the state object identifies this run of the block.
local running: { [number]: State } = {}

-- Blocks have no close hook; a process answering after the pane closed must not render it.
local function alive(state: State): boolean
	if running[state.cx.pane] ~= state then
		return false
	end
	for _, p in tern.pane.list() do
		if p.pane == state.cx.pane then
			return true
		end
	end
	running[state.cx.pane] = nil
	return false
end

local function num(x: any): number
	return if type(x) == "number" then x else 0
end

-- `omp stats` covers about the last day; models sort by cost. Only names and totals are read.
local function read_models(data: any): { since: number, rows: { Model } }?
	if type(data) ~= "table" or type(data.byModel) ~= "table" then
		return nil
	end
	local rows: { Model } = {}
	for _, m in data.byModel do
		if type(m) == "table" and type(m.model) == "string" then
			table.insert(rows, {
				name = m.model,
				cost = num(m.totalCost),
				requests = num(m.totalRequests),
				cache = num(m.cacheRate),
				tps = num(m.avgTokensPerSecond),
			})
		end
	end
	table.sort(rows, function(a, b)
		return a.cost > b.cost
	end)
	local since = type(data.overall) == "table" and num(data.overall.firstTimestamp) or 0
	return { since = since // 1000, rows = rows }
end

-- History first, then stats from its callback: one process per callback, as Tern's 50 ms budget asks.
local function load(state: State)
	if state.loading then
		return
	end
	state.loading = true
	config.load()
	local ok, days = pcall(tern.kv.get, "days")
	state.days = if ok and type(days) == "table" then days else {}
	local function stats()
		local started = pcall(tern.process.run, { OMP, "stats", "--json" }, { timeout_ms = 60000 }, function(res)
			if not alive(state) then
				return
			end
			state.loading = false
			local decoded, data = pcall(tern.json.decode, res.stdout)
			if res.status == 0 and decoded then
				state.models = read_models(data)
			end
			state.cx:render()
		end)
		if not started then
			state.loading = false
		end
	end
	local argv = { OMP, "usage", "--history", "--json", "--days", "7" }
	local started = pcall(tern.process.run, argv, { timeout_ms = 60000 }, function(res)
		if not alive(state) then
			return
		end
		local decoded, data = pcall(tern.json.decode, res.stdout)
		state.failed = not (res.status == 0 and decoded and type(data) == "table" and type(data.entries) == "table")
		if not state.failed then
			state.series = history.series(data.entries)
			state.groups = history.groups(data.entries)
			state.fetched = os.time()
		end
		state.cx:render()
		stats()
	end)
	if not started then
		state.loading = false
		state.failed = true
	end
end

local function pct(f: number): string
	return string.format("%d%%", math.floor(f * 100 + 0.5))
end

local function usage_cards(series: { [string]: { { number } } }, groups: { any }): { Node }
	local cards: { Node } = {}
	for _, group in groups do
		local rows: { Node } = {}
		for _, limit in group.limits do
			local points = series[limit.id]
			if points and #points > 0 then
				local now = points[#points][2]
				local spark: { { any } } = {}
				for _, p in points do
					table.insert(spark, { os.date("%m-%d %Hh", p[1]), math.floor(p[2] * 100 + 0.5) })
				end
				table.insert(rows, ui.meter(math.clamp(now, 0, 1), limit.label .. " " .. pct(now)))
				table.insert(rows, ui.spark(spark))
			end
		end
		if #rows > 0 then
			table.insert(cards, ui.card(group.name, rows))
		end
	end
	return cards
end

local function models_card(models: { since: number, rows: { Model } }): Node?
	if #models.rows == 0 then
		return nil
	end
	local L = config.labels
	local items: { { Spans } } = {}
	for _, m in models.rows do
		local detail = string.format(L.dash_model_row, string.format("$%.2f", m.cost), m.requests, math.floor(m.cache * 100 + 0.5), math.floor(m.tps + 0.5))
		table.insert(items, { m.name, detail })
	end
	return ui.card(string.format(L.dash_models, os.date("%d/%m %H:%M", models.since)), { ui.kv(items) })
end

local function cost_card(days: { [string]: any }): Node
	local L = config.labels
	if next(days) == nil then
		return ui.card(L.dash_cost, { ui.text(ui.span(L.dash_cost_empty, "muted")) })
	end
	local c = history.costs(days, os.time())
	local function money(n: number): string
		return string.format("$%.0f", n)
	end
	return ui.card(L.dash_cost, {
		ui.kv({ { L.dash_today, money(c.today) }, { L.dash_week, money(c.week) }, { L.dash_month, money(c.month) } }),
		ui.bars(c.last7),
	})
end

tern.block.define("dashboard", {
	init = function(cx: BlockCx, _args: { string }, _saved: any): State
		local state: State = { cx = cx, series = nil, groups = nil, models = nil, days = {}, failed = false, loading = false, fetched = nil }
		running[cx.pane] = state
		load(state)
		return state
	end,

	title = function(_state: State): string?
		return "OMP usage"
	end,

	view = function(state: State, _cx: BlockCx): BlockView
		local L = config.labels
		local parts: { Node } = {}
		if state.series and state.groups then
			for _, card in usage_cards(state.series, state.groups) do
				table.insert(parts, card)
			end
			if #parts == 0 then
				table.insert(parts, ui.text(ui.span(L.dash_no_history, "muted")))
			end
		elseif state.failed then
			table.insert(parts, ui.text(ui.span(L.dash_failed, "warning")))
		else
			table.insert(parts, ui.progress(nil, L.dash_loading))
		end
		table.insert(parts, cost_card(state.days))
		local models = state.models and models_card(state.models)
		if models then
			table.insert(parts, models)
		end
		local status: { Span | string } = {}
		if state.fetched then
			table.insert(status, ui.span(string.format(L.dash_updated, os.date("%H:%M", state.fetched)), "muted"))
		end
		table.insert(status, ui.span("  r " .. L.dash_refresh, "dim"))
		return { main = ui.col(parts), dock = ui.col({ ui.text(status) }) }
	end,

	key = function(state: State, key: Key, _cx: BlockCx): boolean?
		if key.ctrl or key.alt or key.meta or (key.text or key.name) ~= "r" then
			return false
		end
		load(state)
		return true
	end,
})

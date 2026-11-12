-- Claude and Codex usage from omp as widgets in Tern's widget bar (usage.luau). See README.md.
local config = require("./config")
local update = require("./update")
local usage = require("./usage")
local FETCH_MS = 5 * 60 * 1000 -- Anthropic usage endpoint answers 429 below ~5 min
local TICK_MS = 60 * 1000
local UPDATE_MS = 60 * 60 * 1000 -- update.check asks GitHub at most once a day; this only looks at the cache

local OMP = config.omp_bin()

local function every(ms: number, fn: () -> ())
	local function loop()
		fn()
		tern.timer(ms, loop)
	end
	loop()
end

local function hidden(id: string, run: (any) -> ())
	tern.command({
		id = id,
		title = "Status line: " .. id,
		available = function()
			return false
		end,
		run = run,
	})
end

tern.command({
	id = "refresh",
	title = "OMP usage: refresh Claude and Codex limits",
	run = function()
		usage.fetch(true)
	end,
})

-- One dashboard per window: focus the open one, else open it beside the focused pane.
local function open_dashboard(cx: WindowCx)
	for _, pane in cx.session:panes() do
		if pane.title == "OMP usage" then
			cx.layout:focus(pane.pane)
			return
		end
	end
	if cx:new_block("omp-usage.dashboard", nil, "beside") == nil then
		cx:toast("error", config.labels.dash_missing)
	end
end

tern.command({
	id = "dashboard",
	title = "OMP usage: dashboard",
	icon = "gauge",
	run = open_dashboard,
})
config.load()
usage.init(OMP)
config.commands()
update.init()
usage.widgets()
update.widget()

-- window_start doesn't fire again after `tern plugin reload`; a load-time timer covers both. Each callback starts
-- one process or request at most: one over 50 ms makes Tern turn off every timer of the plugin until a reload.
tern.timer(0, function()
	every(FETCH_MS, usage.fetch)
end)
tern.timer(1000, function()
	every(FETCH_MS, usage.fetch_today)
end)
tern.timer(2000, function(cx)
	if cx then
		update.greet(cx)
	end
	local function look(later)
		update.check(false, later)
		tern.timer(UPDATE_MS, look)
	end
	look(cx)
end)
tern.timer(TICK_MS, function()
	-- The countdown moves without new data, and another window may have changed a setting; a new language renames
	-- the widgets in the gallery. usage.paint() also redraws the bar.
	local language = config.get("language")
	every(TICK_MS, function()
		config.load()
		if config.get("language") ~= language then
			language = config.get("language")
			usage.widgets()
			update.widget()
		end
		usage.paint()
	end)
end)

-- Personal widgets and segments: extras.luau beside window.luau (git ignores it), else the copy an update moved to the
-- data folder, because `tern plugin install --force` replaces this folder. Segments go to "Plugin segments".
local function load_extras(): any?
	local ok, mod = pcall(require, "./extras")
	if ok then
		return mod
	end
	local kept = tern.plugin.data .. "/extras.luau"
	if not tern.fs.exists(kept) then
		return nil
	end
	local chunk = loadstring(tern.fs.read(kept), "=extras.luau")
	local loaded, result = pcall(chunk or error)
	return if loaded then result else nil
end
local extras = load_extras()
if extras then
	extras.init(hidden, every)
	if extras.segments then
		tern.chrome.status(function(pane)
			local out = {}
			extras.segments(out, pane)
			return out
		end)
	end
end

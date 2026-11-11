-- Claude and Codex usage from omp in Tern's status line (usage.luau). See README.md.
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
hidden("today", open_dashboard)
hidden("cost", open_dashboard)
usage.init(OMP, hidden)
config.load()
config.commands()
update.init()

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
	-- The countdown moves without new data, and another window may have changed a setting.
	every(TICK_MS, function()
		config.load()
		tern.chrome.refresh()
	end)
end)

tern.css("statusline", [[
/* Tern spaces plugin segments with a flex gap; zero it and let each segment set its own margin.
   Descendant, not child: since Tern 0.9.16 .sl-plugins sits inside a .sb-grp. */
#statusline .sl-plugins { gap: 0 !important; }
#statusline .sl-plugins > .sl-plugin { margin-left: 6px; }
#statusline .sl-plugin[title^="plugin.omp-usage."] { margin: 0 0 0 6px; padding: 0; }
#statusline .sl-plugin[title="plugin.omp-usage.claude"] { margin-left: 16px; padding-left: 12px;
  border-left: 1px solid rgb(255 255 255 / 10%); color: #d97757; font-weight: 600; }
#statusline .sl-plugin[title="plugin.omp-usage.codex"] { margin-left: 16px; padding-left: 12px;
  border-left: 1px solid rgb(255 255 255 / 10%); color: #3b82f6; font-weight: 700; }
#statusline .sl-plugin[title="plugin.omp-usage.today"] { margin-left: 16px; padding-left: 12px;
  border-left: 1px solid rgb(255 255 255 / 10%); color: #fb923c; font-weight: 600; }
#statusline .sl-plugin[title="plugin.omp-usage.cost"] { margin-left: 8px; padding: 0 6px; border-radius: 4px;
  color: #4ade80; background: rgb(74 222 128 / 12%); font-weight: 700; }
#statusline .sl-plugin[title="plugin.omp-usage.credits"] { color: #c084fc; }
#statusline .sl-plugin[title="plugin.omp-usage.slack-ok"] { margin-left: 10px; padding: 0 6px; border-radius: 4px;
  color: #4ade80; background: rgb(74 222 128 / 12%); font-weight: 700; }
#statusline .sl-plugin[title="plugin.omp-usage.slack-bad"] { margin-left: 10px; padding: 0 6px; border-radius: 4px;
  color: #f87171; background: rgb(239 68 68 / 18%); font-weight: 700; animation: omppulse 1.2s ease-in-out infinite; }
#statusline .sl-plugin[title="plugin.omp-usage.reset"] { color: rgb(255 255 255 / 45%); }
#statusline .sl-plugin[title="plugin.omp-usage.reset-soon"] { color: #4ade80; font-weight: 600; }
#statusline .sl-plugin[title="plugin.omp-usage.eta"] { margin-left: 4px; color: #fb923c; font-weight: 600; }
#statusline .sl-plugin[title="plugin.omp-usage.locked"] { margin-left: 16px; color: #fff; background: #b91c1c;
  padding: 0 6px; border-radius: 4px; font-weight: 700; animation: omppulse 0.9s ease-in-out infinite; }
#statusline .sl-plugin[title^="plugin.omp-usage.dot-"] { margin-left: 0; }
#statusline .sl-plugin[title="plugin.omp-usage.dot-1"] { margin-left: 6px; color: #22c55e; }
#statusline .sl-plugin[title="plugin.omp-usage.dot-2"] { color: #a3e635; }
#statusline .sl-plugin[title="plugin.omp-usage.dot-3"] { color: #facc15; }
#statusline .sl-plugin[title="plugin.omp-usage.dot-4"] { color: #f97316; }
#statusline .sl-plugin[title="plugin.omp-usage.dot-5"] { color: #ef4444; }
#statusline .sl-plugin[title="plugin.omp-usage.empty"] { color: rgb(255 255 255 / 14%); }
#statusline .sl-plugin[title^="plugin.omp-usage.dot-"] + .sl-plugin[title="plugin.omp-usage.empty"] { margin-left: 0; }
#statusline .sl-plugin[title="plugin.omp-usage.pct-1"] { color: #22c55e; }
#statusline .sl-plugin[title="plugin.omp-usage.pct-2"] { color: #a3e635; }
#statusline .sl-plugin[title="plugin.omp-usage.pct-3"] { color: #facc15; }
#statusline .sl-plugin[title="plugin.omp-usage.pct-4"] { color: #f97316; font-weight: 600; }
#statusline .sl-plugin[title="plugin.omp-usage.pct-crit"] { color: #fff; font-weight: 700; background: #dc2626;
  padding: 0 4px; border-radius: 3px; animation: omppulse 1.2s ease-in-out infinite; }
#statusline .sl-plugin[title="plugin.omp-usage.update"] { margin-left: 10px; padding: 0 6px; border-radius: 4px;
  color: #fff; background: #2563eb; font-weight: 700; }
@keyframes omppulse { 50% { opacity: 0.35; } }
]])

-- Personal segments: extras.luau beside window.luau (git ignores it), else the copy an update moved to the
-- data folder, because `tern plugin install --force` replaces this folder.
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
end

tern.chrome.status(function(pane)
	local out = {}
	if extras then
		extras.segments(out, pane)
	end
	-- First, so a narrow window that clips the end of the status line still shows it.
	update.segments(out)
	usage.segments(out)
	return out
end)

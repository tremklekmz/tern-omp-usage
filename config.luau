-- Settings changed from the palette, kept in tern.kv (the plugin's data folder) so a reinstall or update keeps them.
local LABELS = require("./labels")

local M = {}

-- What the palette can turn off, with its default; a new feature that starts off gets `false`. What the bar shows is
-- the widgets placed in Tern's widget bar (palette › Edit widgets…), so it isn't a setting here.
M.PARTS = {
	updates = true,
	alerts = true,
}
M.LANGUAGES = { "en", "pt-BR", "es", "zh-CN", "ja", "de", "fr" }

local DEFAULTS = { language = "en", workdays = 5, crit = 0.8 }

for name, words in LABELS do
	if name ~= "en" then
		setmetatable(words, { __index = LABELS.en })
	end
end

local saved: { [string]: any } = {}
M.labels = LABELS.en

-- Tern's app and daemon may not inherit the shell PATH, so prefer the omp that Tern itself manages.
local function managed_omp(): string?
	local paths: { string } = {}
	local local_app = tern.getenv("LOCALAPPDATA")
	if local_app then
		table.insert(paths, local_app .. "\\Tern\\omp\\bin\\omp.exe")
	end
	local home = tern.getenv("HOME")
	if home then
		table.insert(paths, home .. "/Library/Application Support/Tern/omp/bin/omp")
		table.insert(paths, (tern.getenv("XDG_DATA_HOME") or home .. "/.local/share") .. "/Tern/omp/bin/omp")
	end
	for _, p in paths do
		if tern.fs.exists(p) then
			return p
		end
	end
	return nil
end

function M.omp_bin(): string
	return tern.getenv("OMP_USAGE_BIN") or managed_omp() or "omp"
end

function M.get(key: string): any
	local v = saved[key]
	return if v == nil then DEFAULTS[key] else v
end

function M.shows(part: string): boolean
	local v = saved.parts and saved.parts[part]
	return if v == nil then M.PARTS[part] == true else v == true
end

local function store()
	tern.kv.set("settings", saved)
	M.labels = LABELS[M.get("language")] or LABELS.en
end

-- Reads the store again; call it at load or from a timer, never from the status formatter (4 ms).
function M.load()
	local ok, v = pcall(tern.kv.get, "settings")
	saved = if ok and type(v) == "table" then v else {}
	M.labels = LABELS[M.get("language")] or LABELS.en
end

function M.set(key: string, value: any)
	saved[key] = value
	store()
end

function M.toggle(part: string): boolean
	local parts = saved.parts or {}
	parts[part] = not M.shows(part)
	saved.parts = parts
	store()
	return parts[part]
end

function M.reset()
	saved = {}
	store()
end

local function names(): string
	local out = {}
	for name in M.PARTS do
		table.insert(out, name)
	end
	table.sort(out)
	return table.concat(out, ", ")
end

-- Each answer returns (ok, toast text); the bar redraws with the new value.
local ANSWERS: { [string]: (string) -> (boolean, string) } = {
	part = function(text)
		local name = string.lower(text)
		if M.PARTS[name] == nil then
			return false, "Not a part: " .. text .. " (" .. names() .. ")"
		end
		return true, name .. ": " .. (if M.toggle(name) then M.labels.on else M.labels.off)
	end,
	language = function(text)
		for _, lang in M.LANGUAGES do
			if string.lower(lang) == string.lower(text) then
				M.set("language", lang)
				return true, "language: " .. lang
			end
		end
		return false, "Not a language: " .. text .. " (" .. table.concat(M.LANGUAGES, ", ") .. ")"
	end,
	workdays = function(text)
		local n = tonumber(text)
		if not n or n ~= math.floor(n) or n < 1 or n > 7 then
			return false, "Work days are a whole number from 1 to 7"
		end
		M.set("workdays", n)
		return true, string.format("work days: %d", n)
	end,
	crit = function(text)
		local n = tonumber((string.gsub(text, "%%", "")))
		if not n or n < 50 or n > 99 then
			return false, "The threshold is a percentage from 50 to 99"
		end
		M.set("crit", n / 100)
		return true, string.format("alert at %d%%", n)
	end,
}

local function asking(id: string, title: string, answer: string, opts: () -> PromptOptions)
	tern.command({
		id = id,
		title = title,
		icon = "gauge",
		run = function(cx)
			cx:prompt(opts()):next(function(text: string?, _err, later)
				local trimmed = text and string.match(text, "^%s*(.-)%s*$")
				if not trimmed or trimmed == "" then
					return
				end
				local ok, msg = ANSWERS[answer](trimmed)
				local where: any = later or cx
				where:toast(if ok then "success" else "error", msg)
				tern.chrome.refresh()
			end)
		end,
	})
end

function M.commands()
	asking("settings-part", "OMP usage: show or hide a part…", "part", function()
		return { placeholder = names(), action = "toggle" }
	end)
	asking("settings-language", "OMP usage: language…", "language", function()
		return { value = M.get("language"), placeholder = table.concat(M.LANGUAGES, ", ") }
	end)
	asking("settings-workdays", "OMP usage: work days per week…", "workdays", function()
		return { value = tostring(M.get("workdays")), placeholder = "1 to 7, counted from Monday (5 = Monday to Friday)" }
	end)
	asking("settings-crit", "OMP usage: red badge threshold…", "crit", function()
		return { value = tostring(math.floor(M.get("crit") * 100 + 0.5)), placeholder = "percent, 50 to 99" }
	end)
	tern.command({
		id = "settings-reset",
		title = "OMP usage: reset settings",
		icon = "gauge",
		run = function(cx)
			M.reset()
			cx:toast("success", "OMP usage settings reset")
			tern.chrome.refresh()
		end,
	})
end

M.answer = ANSWERS

return M

-- Runs update.luau against a fake `tern`: the GitHub answer, the daily cache, the toasts, the reinstall.
-- Run: luau tests/update_test.luau (from the repository root, or via scripts/check.py).

local store: { [string]: any } = {}
local files: { [string]: string } = { ["plugin.toml"] = 'schema = 1\nid = "omp-usage"\nversion = "0.4.0"\n' }
local env_vars: { [string]: string } = {}
local fetches = 0
local release: any = { tag_name = "v0.5.0", html_url = "https://github.com/joaodutra88/tern-omp-usage/releases/tag/v0.5.0" }
local status = 200
local ran: { string }? = nil
local ran_opts: { [string]: any }? = nil
local install_result = { status = 0, stdout = "", stderr = "" }

local fake = {
	kv = {
		get = function(key: string)
			return store[key]
		end,
		set = function(key: string, value: any)
			store[key] = value
		end,
	},
	fs = {
		exists = function(path: string)
			return files[path] ~= nil
		end,
		read = function(path: string)
			return assert(files[path], "no file " .. path)
		end,
		write = function(path: string, text: string)
			files[path] = text
		end,
	},
	getenv = function(name: string)
		return env_vars[name]
	end,
	fetch = function(_url: string, _opts, done)
		fetches += 1
		done({ status = status, body = release, headers = {} }, nil)
	end,
	json = {
		decode = function(body: any)
			return body
		end,
	},
	process = {
		run = function(argv: { string }, opts, done)
			ran = argv
			ran_opts = opts
			done(install_result, nil)
		end,
	},
	chrome = { refresh = function() end },
	command = function() end,
	plugin = { data = "DATA" },
}

local config = require("../config")
local update = require("../update")
-- Why: the luau CLI freezes _G; each module's own environment stays writable and is read at call time.
local config_env: any = getfenv(config.load)
config_env.tern = fake
local update_env: any = getfenv(update.check)
update_env.tern = fake
config.load()
update.init()

local function expect(cond: boolean, msg: string)
	if not cond then
		error(msg, 2)
	end
end

local toasts: { { string } } = {}
local cx = {
	toast = function(_self, level: string, text: string, sub: string?)
		table.insert(toasts, { level, text, sub or "" })
	end,
}

local function bar(): string
	local out = {}
	update.segments(out)
	return if out[1] then out[1].text else ""
end

expect(update.VERSION == "0.4.0", "the version comes from plugin.toml")
expect(update.newer("0.10.0", "0.9.9"), "versions compare as numbers, not text")
expect(not update.newer("v0.4.0", "0.4.0"), "a leading v is the same version")
expect(not update.newer("1.0", "1.0.0"), "missing parts count as 0")

-- A newer release: the ⬆ segment and one toast.
update.check(false, cx)
expect(fetches == 1, "the first check asks GitHub")
expect(bar() == "⬆ 0.5.0", "a newer release shows ⬆ with its version, got: " .. bar())
expect(#toasts == 1 and toasts[1][2] == "OMP usage 0.5.0 is out", "one toast announces it")

-- Within a day the cache answers, and the toast doesn't repeat.
update.check(false, cx)
expect(fetches == 1, "a second check the same day reads the cache")
expect(#toasts == 1, "the same version is announced once")

-- A day later GitHub is asked again.
store.update.checked_at -= 86401
update.check(false, cx)
expect(fetches == 2, "after a day the check asks GitHub again")

-- Turned off from the palette: no segment, no request; the palette's forced check still answers.
config.answer.part("updates")
expect(bar() == "", "updates off hides ⬆")
store.update.checked_at -= 86401
update.check(false, cx)
expect(fetches == 2, "updates off makes no request")
update.check(true, cx)
expect(fetches == 3 and toasts[#toasts][2] == "OMP usage 0.5.0 is out", "a forced check asks and answers")
config.answer.part("updates")

env_vars.OMP_USAGE_NO_UPDATE_CHECK = "1"
expect(bar() == "", "OMP_USAGE_NO_UPDATE_CHECK hides ⬆")
env_vars.OMP_USAGE_NO_UPDATE_CHECK = nil

-- Same version as installed: nothing to show; a forced check says so.
release = { tag_name = "v0.4.0", html_url = "x" }
update.check(true, cx)
expect(bar() == "", "the installed version is not an update")
expect(toasts[#toasts][2] == "OMP usage 0.4.0 is the latest", "a forced check reports up to date")

-- GitHub down: a forced check says it failed and keeps the last answer.
status = 503
update.check(true, cx)
expect(toasts[#toasts][1] == "error", "a failed forced check is an error toast")
status = 200

-- Reinstall: extras.luau moves to the data folder first, then tern replaces the package.
files["extras.luau"] = "return {}"
update.install(cx)
expect(files["DATA/extras.luau"] == "return {}", "extras.luau is copied to the data folder before installing")
expect(ran ~= nil and ran[2] == "plugin" and ran[3] == "install" and ran[5] == "--force", "the update reinstalls with --force")
expect(ran ~= nil and ran[4] == "https://github.com/tremklekmz/tern-omp-usage", "from the repository")
-- Windows refuses to replace a folder a process runs in, and the default cwd is the plugin's own folder.
expect(ran_opts ~= nil and ran_opts.cwd == "DATA", "the reinstall runs outside the plugin folder")

install_result = { status = 1, stdout = "", stderr = "omp-usage is linked (C:\\src\\tern-omp-usage); use unlink first\n" }
update.install(cx)
expect(toasts[#toasts][2] == "Linked checkout: update it with git pull", "a linked checkout points to git pull")

-- After an update the new version says so once; a first install stays quiet.
toasts = {}
store.seen_version = nil
update.greet(cx)
expect(#toasts == 0 and store.seen_version == "0.4.0", "a first install shows no toast")
store.seen_version = "0.3.1"
update.greet(cx)
expect(#toasts == 1 and toasts[1][2] == "OMP usage updated to 0.4.0", "an update shows its version")
update.greet(cx)
expect(#toasts == 1, "the update toast shows once")

print("update_test: ok")

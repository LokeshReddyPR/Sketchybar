-- Aerospace-independent fallback shown ONLY when AeroSpace is not running.
-- Displays icons of the currently open apps (from macOS, no aerospace) with the
-- active app highlighted red. When AeroSpace IS running the workspace pills in
-- items/spaces.lua handle this, and this pill stays hidden.

local appearance = require("appearance")
local app_icons = require("helpers.app_icons")
local sbar = require("sketchybar")
local colors = require("appearance").colors

local MAX_APPS = 15
local style = appearance.styles.workspace

-- List open GUI apps by display name (matches the app_icons keys). Full paths
-- because sketchybar's launchd service has a minimal PATH.
local get_apps =
	"/usr/bin/osascript -e 'tell application \"System Events\" to get displayed name of every process whose background only is false'"
-- "up" only if AeroSpace responds to a query, else "down". (Checking the
-- process isn't enough: `aerospace disable` leaves it running but unresponsive,
-- and a valid focused-workspace reply is a single token with no spaces.)
local check_aerospace =
	"out=$(/opt/homebrew/bin/aerospace list-workspaces --focused 2>/dev/null); case \"$out\" in *' '*|'') echo down;; *) echo up;; esac"

-- Fixed pool of app-icon items (position left, hidden by default)
local pool = {}
local member_names = {}
for k = 1, MAX_APPS do
	local a = sbar.add("item", "apps.icon." .. k, {
		position = "left",
		drawing = false,
		width = 0,
		background = { drawing = false },
		icon = {
			drawing = true,
			color = style.label.color,
			font = style.label.font,
			padding_left = 4,
			padding_right = 4,
			y_offset = style.label.y_offset,
		},
		label = { drawing = false },
	})
	pool[k] = a
	member_names[k] = a.name
end

-- The pill (navy + blue border) around the icons
local bracket = sbar.add("bracket", "apps.bracket", member_names, {
	background = {
		color = style.background.color,
		border_color = style.background.border_color,
		border_width = style.background.border_width,
		corner_radius = style.background.corner_radius,
		drawing = true,
	},
})
bracket:set({ drawing = false }) -- start hidden

local front_app = ""
local last_sig = nil

local function hide()
	if last_sig == "hidden" then
		return
	end
	for k = 1, MAX_APPS do
		pool[k]:set({ drawing = false, width = 0 })
	end
	bracket:set({ drawing = false })
	last_sig = "hidden"
end

local function render(result)
	-- Parse the comma-separated app list
	local apps = {}
	for raw_name in string.gmatch(result or "", "([^,]+)") do
		local name = raw_name:match("^%s*(.-)%s*$")
		if name ~= "" then
			apps[#apps + 1] = name
		end
	end

	-- Nothing to show (e.g. osascript returned empty) → keep the pill hidden
	if #apps == 0 then
		hide()
		return
	end

	-- Only re-draw when the app list or the active app actually changed
	local sig = table.concat(apps, ",") .. "|" .. front_app
	if sig == last_sig then
		return
	end
	last_sig = sig

	for k = 1, MAX_APPS do
		local app = apps[k]
		if app then
			local icon = app_icons[app] or app_icons["Default"]
			local is_active = app == front_app
			pool[k]:set({
				drawing = true,
				width = "dynamic",
				icon = {
					string = icon,
					color = is_active and colors.red or colors.blue,
					padding_left = (k == 1) and 12 or 4,
					padding_right = (k == #apps) and 12 or 4,
				},
			})
		else
			pool[k]:set({ drawing = false, width = 0 })
		end
	end
	bracket:set({ drawing = true })
end

local function update()
	sbar.exec(check_aerospace, function(state)
		if (state or ""):match("up") then
			hide()
		else
			sbar.exec(get_apps, render)
		end
	end)
end

-- Event-driven (no timer): AeroSpace has no enable/disable event, but these all
-- fire regardless of AeroSpace, and each is a moment the display could change.
-- On each we run one AeroSpace check and show/hide accordingly.
local watcher = sbar.add("item", { drawing = false, updates = true })
watcher:subscribe("front_app_switched", function(env)
	front_app = env.INFO or front_app
	update()
end)
watcher:subscribe({ "space_windows_change", "aerospace_workspace_change", "aerospace_changed", "system_woke", "forced" }, update)

-- Initial render. The immediate call can run before the event loop is ready,
-- so also kick once shortly after load (one-shot, not a poll).
update()
sbar.delay(1, update)

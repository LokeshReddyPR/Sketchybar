-- OmniWM workspace pills.
--
-- Renders one rounded pill per OmniWM workspace: the workspace number followed
-- by an icon for each distinct app it contains, ordered left-to-right to match
-- the tiling layout. The focused workspace and the focused app icon are
-- highlighted red. Empty, unfocused, off-screen workspaces are hidden.
--
-- Data comes from OmniWM's CLI (`omniwmctl`, requires IPC enabled in the OmniWM
-- menu bar). Two queries are transformed by `jq` into simple pipe-delimited
-- lines so parsing stays trivial and robust (no nested-JSON decoding in Lua):
--   workspaces -> "number|isFocused|isVisible|isCurrent|total"
--   windows    -> "wsNumber|appName|frameX|frameY|isFocused"
-- Instant updates are driven by helpers/omniwm/watch.sh (fires the custom
-- `omniwm_workspace_change` event); a slow poll is kept as a safety net.

local appearance = require("appearance")
local app_icons = require("helpers.app_icons")
local sbar = require("sketchybar")
local colors = require("appearance").colors

-- Max number of distinct app icons shown per workspace (fixed item pool)
local MAX_APPS = 8

-- Full paths: SketchyBar's launchd service runs with a minimal PATH.
local OMNIWMCTL = "/opt/homebrew/bin/omniwmctl"
local JQ = "/opt/homebrew/bin/jq"

local get_workspaces = OMNIWMCTL
	.. " query workspaces 2>/dev/null | "
	.. JQ
	.. [[ -r '.result.payload.workspaces[] | "\(.number)|\(.isFocused)|\(.isVisible)|\(.isCurrent)|\(.counts.total)"']]
local get_windows = OMNIWMCTL
	.. " query windows 2>/dev/null | "
	.. JQ
	.. [[ -r '.result.payload.windows[] | "\(.workspace.number)|\(.app.name)|\(.frame.x)|\(.frame.y)|\(.isFocused)"']]

-- Root is used to handle event subscriptions
local root = sbar.add("item", { drawing = false })

-- Custom event fired by helpers/omniwm/watch.sh on OmniWM focus/workspace/window
-- changes, for instant pill updates.
sbar.add("event", "omniwm_workspace_change")

local numbers = {} -- ws number -> number item ("N:")
local app_pool = {} -- ws number -> { app icon item, ... } (fixed pool)
local brackets = {} -- ws number -> bracket item (the pill border)
local spacers = {} -- ws number -> gap item after the pill (NOT bracketed)

local WORKSPACE_GAP = 6 -- px of space between adjacent workspace pills

-- Cached last-applied state so we only touch items that actually changed.
-- Re-setting width="dynamic" on every update is what made icons pop in width.
local number_state = {} -- ws number -> signature string
local app_state = {} -- ws number -> { k -> signature string ("off" when hidden) }
local bracket_state = {} -- ws number -> bool (drawing)
local spacer_state = {} -- ws number -> bool (drawing)

-- Parse the jq workspace lines into an ordered list of workspace records.
local function parseWorkspaces(str)
	local list = {}
	if type(str) ~= "string" then
		return list
	end
	for line in str:gmatch("[^\r\n]+") do
		local num, foc, vis, cur, total = line:match("^(%d+)|(%a+)|(%a+)|(%a+)|(%d+)$")
		if num then
			list[#list + 1] = {
				num = tonumber(num),
				focused = foc == "true",
				visible = vis == "true",
				current = cur == "true",
				total = tonumber(total),
			}
		end
	end
	return list
end

-- Parse the jq window lines into: ws number -> ordered distinct app names, plus
-- the app owning the currently focused window.
local function parseWindows(str)
	local byws = {} -- ws number -> { {app=, x=, y=, idx=}, ... }
	local focused_app = nil
	if type(str) == "string" then
		for line in str:gmatch("[^\r\n]+") do
			local ws, app, x, y, foc = line:match("^(%d+)|(.-)|(%-?%d+)|(%-?%d+)|(%a+)$")
			if ws then
				ws = tonumber(ws)
				byws[ws] = byws[ws] or {}
				table.insert(byws[ws], { app = app, x = tonumber(x), y = tonumber(y), idx = #byws[ws] + 1 })
				if foc == "true" then
					focused_app = app
				end
			end
		end
	end

	-- Order each workspace's windows left-to-right (x, then y) to match tiling,
	-- then collapse to distinct apps preserving first appearance.
	local apps_by_ws = {}
	for ws, wins in pairs(byws) do
		table.sort(wins, function(a, b)
			if a.x ~= b.x then
				return a.x < b.x
			end
			if a.y ~= b.y then
				return a.y < b.y
			end
			return a.idx < b.idx
		end)
		local apps, seen = {}, {}
		for _, w in ipairs(wins) do
			if not seen[w.app] then
				seen[w.app] = true
				apps[#apps + 1] = w.app
			end
		end
		apps_by_ws[ws] = apps
	end
	return apps_by_ws, focused_app
end

local function updateWorkspace(num, info)
	local open_windows = info.apps or {}
	local is_focused = info.focused
	local is_visible = info.visible
	local focused_app = info.focused_app

	local number = numbers[num]
	local apps = app_pool[num]
	local bracket = brackets[num]
	if app_state[num] == nil then
		app_state[num] = {}
	end
	local astate = app_state[num]

	local has_apps = #open_windows > 0

	-- Set an item's drawing/width only on show/hide transitions; once an icon is
	-- visible, only its content (string/color/padding) is updated. This is what
	-- stops the width from popping on every workspace/app change.
	local function setBracket(drawing)
		if bracket_state[num] ~= drawing then
			bracket:set({ drawing = drawing })
			bracket_state[num] = drawing
		end
	end
	local function setSpacer(shown)
		if spacer_state[num] ~= shown then
			spacers[num]:set({ drawing = shown, width = shown and WORKSPACE_GAP or 0 })
			spacer_state[num] = shown
		end
	end
	local function setNumber(props, sig)
		if number_state[num] ~= sig then
			sbar.animate("tanh", 15, function()
				number:set(props)
			end)
			number_state[num] = sig
		end
	end
	local function hideApp(k)
		if astate[k] ~= "off" then
			apps[k]:set({ drawing = false, width = 0 })
			astate[k] = "off"
		end
	end
	local function showApp(k, icon, color, pr, sig)
		if astate[k] == nil or astate[k] == "off" then
			-- Transition hidden -> shown: this is the only time we set width.
			apps[k]:set({
				drawing = true,
				width = "dynamic",
				icon = { string = icon, color = color, padding_right = pr },
			})
		elseif astate[k] ~= sig then
			-- Already shown: update content only, leave width/drawing untouched.
			sbar.animate("tanh", 15, function()
				apps[k]:set({ icon = { string = icon, color = color, padding_right = pr } })
			end)
		end
		astate[k] = sig
	end

	-- Hide the whole workspace: empty, not focused, not visible
	if not has_apps and not is_focused and not is_visible then
		setNumber({ drawing = false }, "hidden")
		for k = 1, MAX_APPS do
			hideApp(k)
		end
		setBracket(false)
		setSpacer(false)
		return
	end

	setBracket(true)
	setSpacer(true)

	-- The workspace number is highlighted red when this workspace is focused
	local num_color = is_focused and colors.red or colors.blue

	-- Empty but shown (focused/visible): number + em dash, no app icons
	if not has_apps then
		setNumber({
			drawing = true,
			icon = { string = num .. ": —", padding_right = 12, color = num_color },
		}, "empty|" .. tostring(is_focused))
		for k = 1, MAX_APPS do
			hideApp(k)
		end
		return
	end

	-- Has apps: number, then one icon item per distinct app
	setNumber({
		drawing = true,
		icon = { string = num .. ":", padding_right = 2, color = num_color },
	}, "num|" .. tostring(is_focused))

	for k = 1, MAX_APPS do
		local app = open_windows[k]
		if app then
			local lookup = app_icons[app]
			local icon = (lookup == nil) and app_icons["Default"] or lookup
			-- Highlight the icon of the currently focused window
			local is_active = is_focused and focused_app == app
			local is_last = k == #open_windows
			local color = is_active and colors.red or colors.blue
			local pr = is_last and 12 or 2
			local sig = icon .. "|" .. tostring(color) .. "|" .. tostring(pr)
			showApp(k, icon, color, pr, sig)
		else
			hideApp(k)
		end
	end
end

-- Build the items for one workspace. Idempotent: does nothing if they already
-- exist, so it can be called again when new workspaces appear.
local function createWorkspace(num)
	if numbers[num] ~= nil then
		return
	end
	local style = appearance.styles.workspace

	-- The workspace number ("N:")
	local number = sbar.add("item", "workspace." .. num, {
		drawing = false,
		background = { drawing = false },
		click_script = OMNIWMCTL .. " command switch-workspace " .. num,
		icon = {
			drawing = true,
			string = num .. ":",
			color = style.icon.color,
			font = style.icon.font,
			padding_left = style.icon.padding_left,
			padding_right = 2,
		},
		label = { drawing = false },
	})
	numbers[num] = number

	-- Fixed pool of per-app icon items (so each can be colored independently)
	local apps = {}
	for k = 1, MAX_APPS do
		local a = sbar.add("item", "workspace." .. num .. ".app." .. k, {
			drawing = false,
			width = 0,
			background = { drawing = false },
			click_script = OMNIWMCTL .. " command switch-workspace " .. num,
			icon = {
				drawing = true,
				color = style.label.color,
				font = style.label.font,
				padding_left = 2,
				padding_right = 2,
				y_offset = style.label.y_offset,
			},
			label = { drawing = false },
		})
		apps[k] = a
	end
	app_pool[num] = apps

	-- Bracket draws the rounded, bordered pill around number + app icons
	local members = { number.name }
	for k = 1, MAX_APPS do
		table.insert(members, apps[k].name)
	end
	local bracket = sbar.add("bracket", "workspace." .. num .. ".bracket", members, {
		background = {
			color = style.background.color,
			border_color = style.background.border_color,
			border_width = style.background.border_width,
			corner_radius = style.background.corner_radius,
			drawing = true,
		},
	})
	brackets[num] = bracket

	-- Invisible spacer AFTER the pill (not a bracket member) to separate adjacent
	-- workspaces. Created after the bracket so it sits to the right.
	local spacer = sbar.add("item", "workspace." .. num .. ".spacer", {
		drawing = false,
		width = 0,
		background = { drawing = false },
		icon = { drawing = false },
		label = { drawing = false },
	})
	spacers[num] = spacer
end

-- Query OmniWM, (re)create any new workspace items, then refresh every pill.
local function tick()
	sbar.exec(get_workspaces, function(ws_str)
		local wslist = parseWorkspaces(ws_str)
		for _, w in ipairs(wslist) do
			createWorkspace(w.num)
		end

		sbar.exec(get_windows, function(win_str)
			local apps_by_ws, focused_app = parseWindows(win_str)

			local meta = {}
			for _, w in ipairs(wslist) do
				meta[w.num] = w
			end

			for num, _ in pairs(numbers) do
				local w = meta[num]
				updateWorkspace(num, {
					apps = apps_by_ws[num] or {},
					focused = w and (w.focused or w.current) or false,
					visible = w and w.visible or false,
					focused_app = focused_app,
				})
			end
		end)
	end)
end

-- Start the event forwarder (instant updates). Idempotent thanks to its own
-- pkill guard, so reloads never stack duplicate watchers.
sbar.exec("$CONFIG_DIR/helpers/omniwm/watch.sh >/dev/null 2>&1 &")

-- Initial build + refresh
tick()

-- Refresh on OmniWM events (forwarded by watch.sh) and app-focus changes.
root:subscribe("omniwm_workspace_change", tick)
root:subscribe("front_app_switched", tick)
root:subscribe("display_change", tick)

-- Safety-net poll in case the watcher isn't running (IPC off, OmniWM restarted).
-- Cheap thanks to memoization: unchanged state = no redraw.
local poller = sbar.add("item", { drawing = false, updates = true, update_freq = 2 })
poller:subscribe("routine", tick)

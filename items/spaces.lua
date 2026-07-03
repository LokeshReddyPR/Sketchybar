local appearance = require("appearance")
local app_icons = require("helpers.app_icons")
local sbar = require("sketchybar")
local colors = require("appearance").colors

-- Max number of distinct app icons shown per workspace (fixed item pool)
local MAX_APPS = 8

local query_workspaces =
	"aerospace list-workspaces --all --format '%{workspace}%{monitor-appkit-nsscreen-screens-id}' --json"

-- Root is used to handle event subscriptions
local root = sbar.add("item", { drawing = false })

-- Custom event fired by aerospace move/join keybindings for instant reordering
sbar.add("event", "window_moved")

local numbers = {} -- workspace_index -> number item ("N:")
local app_pool = {} -- workspace_index -> { app icon item, ... } (fixed pool)
local brackets = {} -- workspace_index -> bracket item (the pill border)
local spacers = {} -- workspace_index -> gap item after the pill (NOT bracketed)

local WORKSPACE_GAP = 6 -- px of space between adjacent workspace pills

-- Cached last-applied state so we only touch items that actually changed.
-- Re-setting width="dynamic" on every update is what made icons pop in width.
local number_state = {} -- workspace_index -> signature string
local app_state = {} -- workspace_index -> { k -> signature string ("off" when hidden) }
local bracket_state = {} -- workspace_index -> bool (drawing)
local spacer_state = {} -- workspace_index -> bool (drawing)
local order_cache = {} -- workspace_index -> last app order (kept while hidden)

local function withWindows(f)
	-- Include the window ID in the query so we can track unique windows
	local get_windows = "aerospace list-windows --monitor all --format '%{workspace}%{app-name}%{window-id}' --json"
	local query_visible_workspaces =
		"aerospace list-workspaces --visible --monitor all --format '%{workspace}%{monitor-appkit-nsscreen-screens-id}' --json"
	local get_focus_workspaces = "aerospace list-workspaces --focused"
	local get_focused_window = "aerospace list-windows --focused --format '%{app-name}' --json"
	-- Prints on-screen window positions as JSON: [{"id":..,"x":..,"y":..}, ...]
	local get_positions = "$CONFIG_DIR/helpers/window_positions/bin/window_positions"

	sbar.exec(get_windows, function(workspace_and_windows)
		-- Collect all unique windows per workspace, preserving discovery order
		local raw = {} -- workspace -> { { app=, id=, idx= }, ... }
		local seen_window = {}
		for _, entry in ipairs(workspace_and_windows) do
			local ws = entry.workspace
			local id = entry["window-id"]
			if not seen_window[id] then
				seen_window[id] = true
				if raw[ws] == nil then
					raw[ws] = {}
				end
				table.insert(raw[ws], { app = entry["app-name"], id = tostring(id), idx = #raw[ws] + 1 })
			end
		end

		sbar.exec(get_positions, function(positions)
			-- Map window id -> {x, y}; only on-screen windows report real positions
			local pos = {}
			if type(positions) == "table" then
				for _, p in ipairs(positions) do
					pos[tostring(p.id)] = { x = p.x, y = p.y }
				end
			end

			sbar.exec(get_focus_workspaces, function(focused_workspaces)
				sbar.exec(query_visible_workspaces, function(visible_workspaces)
					sbar.exec(get_focused_window, function(focused_window)
						-- The app owning the currently focused window (highlighted red)
						local focused_app = nil
						if type(focused_window) == "table" and focused_window[1] then
							focused_app = focused_window[1]["app-name"]
						end

						-- Which workspaces are currently on-screen (positions valid)
						local visible_set = {}
						for _, v in ipairs(visible_workspaces) do
							visible_set[v.workspace] = true
						end

						local open_windows = {}
						for ws, wins in pairs(raw) do
							local apps
							if visible_set[ws] then
								-- On-screen: order left-to-right (x, then y) to match tiling.
								table.sort(wins, function(a, b)
									local pa, pb = pos[a.id], pos[b.id]
									local ax = pa and pa.x or math.huge
									local bx = pb and pb.x or math.huge
									if ax ~= bx then
										return ax < bx
									end
									local ay = pa and pa.y or math.huge
									local by = pb and pb.y or math.huge
									if ay ~= by then
										return ay < by
									end
									return a.idx < b.idx
								end)
								apps = {}
								local seen_app = {}
								for _, win in ipairs(wins) do
									if not seen_app[win.app] then
										seen_app[win.app] = true
										apps[#apps + 1] = win.app
									end
								end
							else
								-- Hidden: windows are parked off-screen (unreliable positions),
								-- so keep the order from when it was last visible and just
								-- reconcile added/removed apps (new ones appended at the end).
								local current = {}
								local seen_app = {}
								for _, win in ipairs(wins) do
									if not seen_app[win.app] then
										seen_app[win.app] = true
										current[#current + 1] = win.app
									end
								end
								local cached = order_cache[ws]
								if cached then
									apps = {}
									local present, placed = {}, {}
									for _, a in ipairs(current) do
										present[a] = true
									end
									for _, a in ipairs(cached) do
										if present[a] and not placed[a] then
											apps[#apps + 1] = a
											placed[a] = true
										end
									end
									for _, a in ipairs(current) do
										if not placed[a] then
											apps[#apps + 1] = a
											placed[a] = true
										end
									end
								else
									apps = current
								end
							end
							order_cache[ws] = apps
							open_windows[ws] = apps
						end

						local args = {
							open_windows = open_windows,
							focused_workspace = (focused_workspaces or ""):match("^%s*(.-)%s*$"),
							visible_workspaces = visible_workspaces,
							focused_app = focused_app,
						}
						f(args)
					end)
				end)
			end)
		end)
	end)
end

local function updateWindow(workspace_index, args)
	local open_windows = args.open_windows[workspace_index] or {}
	local focused_workspace = args.focused_workspace
	local visible_workspaces = args.visible_workspaces
	local focused_app = args.focused_app

	local number = numbers[workspace_index]
	local apps = app_pool[workspace_index]
	local bracket = brackets[workspace_index]
	if app_state[workspace_index] == nil then
		app_state[workspace_index] = {}
	end
	local astate = app_state[workspace_index]

	local has_apps = #open_windows > 0

	-- Is this workspace currently visible on some monitor?
	local visible_monitor = nil
	for _, vw in ipairs(visible_workspaces) do
		if vw["workspace"] == workspace_index then
			visible_monitor = vw["monitor-appkit-nsscreen-screens-id"]
			break
		end
	end
	local is_focused = workspace_index == focused_workspace
	local is_visible = visible_monitor ~= nil

	-- Set an item's drawing/width only on show/hide transitions; once an icon
	-- is visible, only its content (string/color/padding) is updated. This is
	-- what stops the width from popping on every workspace/app change.
	local function setBracket(drawing)
		if bracket_state[workspace_index] ~= drawing then
			bracket:set({ drawing = drawing })
			bracket_state[workspace_index] = drawing
		end
	end
	local function setSpacer(shown)
		if spacer_state[workspace_index] ~= shown then
			spacers[workspace_index]:set({ drawing = shown, width = shown and WORKSPACE_GAP or 0 })
			spacer_state[workspace_index] = shown
		end
	end
	local function setNumber(props, sig)
		if number_state[workspace_index] ~= sig then
			-- Animate only the color/appearance change (no width involved here)
			sbar.animate("tanh", 15, function()
				number:set(props)
			end)
			number_state[workspace_index] = sig
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
			-- Animate so the focus-highlight color fades in/out smoothly.
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
			icon = { string = workspace_index .. ": —", padding_right = 12, color = num_color },
		}, "empty|" .. tostring(is_focused))
		for k = 1, MAX_APPS do
			hideApp(k)
		end
		return
	end

	-- Has apps: number, then one icon item per app
	setNumber({
		drawing = true,
		icon = { string = workspace_index .. ":", padding_right = 2, color = num_color },
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

local function updateWindows()
	withWindows(function(args)
		for workspace_index, _ in pairs(numbers) do
			updateWindow(workspace_index, args)
		end
	end)
end

local function updateWorkspaceMonitor()
	local workspace_monitor = {}
	sbar.exec(query_workspaces, function(workspaces_and_monitors)
		for _, entry in ipairs(workspaces_and_monitors) do
			local space_index = entry.workspace
			local monitor_id = math.floor(entry["monitor-appkit-nsscreen-screens-id"])
			workspace_monitor[space_index] = monitor_id
		end
		for workspace_index, number in pairs(numbers) do
			local disp = workspace_monitor[workspace_index]
			if disp then
				number:set({ display = disp })
				for _, a in ipairs(app_pool[workspace_index]) do
					a:set({ display = disp })
				end
				brackets[workspace_index]:set({ display = disp })
				spacers[workspace_index]:set({ display = disp })
			end
		end
	end)
end

sbar.exec(query_workspaces, function(workspaces_and_monitors)
	for _, entry in ipairs(workspaces_and_monitors) do
		local workspace_index = entry.workspace
		local style = appearance.styles.workspace

		-- The workspace number ("N:") — always blue, never highlighted
		local number = sbar.add("item", "workspace." .. workspace_index, {
			drawing = false,
			background = { drawing = false },
			click_script = "aerospace workspace " .. workspace_index,
			icon = {
				drawing = true,
				string = workspace_index .. ":",
				color = style.icon.color,
				font = style.icon.font,
				padding_left = style.icon.padding_left,
				padding_right = 2,
			},
			label = { drawing = false },
		})
		numbers[workspace_index] = number

		-- Fixed pool of per-app icon items (so each can be colored independently)
		local apps = {}
		for k = 1, MAX_APPS do
			local a = sbar.add("item", "workspace." .. workspace_index .. ".app." .. k, {
				drawing = false,
				width = 0,
				background = { drawing = false },
				click_script = "aerospace workspace " .. workspace_index,
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
		app_pool[workspace_index] = apps

		-- Bracket draws the rounded, bordered pill around number + app icons
		local members = { number.name }
		for k = 1, MAX_APPS do
			table.insert(members, apps[k].name)
		end
		local bracket = sbar.add("bracket", "workspace." .. workspace_index .. ".bracket", members, {
			background = {
				color = style.background.color,
				border_color = style.background.border_color,
				border_width = style.background.border_width,
				corner_radius = style.background.corner_radius,
				drawing = true,
			},
		})
		brackets[workspace_index] = bracket

		-- Invisible spacer AFTER the pill (not a bracket member) to separate
		-- adjacent workspaces. Created after the bracket so it sits to the right.
		local spacer = sbar.add("item", "workspace." .. workspace_index .. ".spacer", {
			drawing = false,
			width = 0,
			background = { drawing = false },
			icon = { drawing = false },
			label = { drawing = false },
		})
		spacers[workspace_index] = spacer
	end

	-- Initial setup
	updateWindows()
	updateWorkspaceMonitor()

	-- Recolor / reflow whenever the workspace, focused window, or displays change
	root:subscribe("aerospace_workspace_change", function()
		updateWindows()
	end)

	root:subscribe("front_app_switched", function()
		updateWindows()
	end)

	-- Fired instantly by aerospace move/join keybindings (see aerospace.toml)
	root:subscribe("window_moved", function()
		updateWindows()
	end)

	root:subscribe("display_change", function()
		updateWorkspaceMonitor()
		updateWindows()
	end)

	-- aerospace emits no event when a window is moved/reordered within a
	-- workspace, so poll periodically to keep the icon order in sync with the
	-- on-screen tiling. Cheap thanks to memoization: unchanged order = no redraw.
	local poller = sbar.add("item", { drawing = false, updates = true, update_freq = 2 })
	poller:subscribe("routine", function()
		updateWindows()
	end)
end)

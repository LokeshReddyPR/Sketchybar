local icons = require("icons")
local colors = require("appearance").colors
local settings = require("settings")
local sbar = require("sketchybar")
local fonts = require("fonts")

-- Battery indicator item
local battery = sbar.add("item", "widgets.battery", {
	position = "right",
	padding_left = 6, -- extra 3px so the gap to the volume bracket matches other items
	update_freq = 180,
	icon = {
		font = { size = 14.0 },
		padding_left = settings.padding.icon_label_item.icon.padding_left,
		padding_right = settings.padding.icon_label_item.icon.padding_right,
	},
	label = {
		padding_right = settings.padding.icon_label_item.label.padding_right,
	},
})

-- Time remaining popup item
local remaining_time = sbar.add("item", {
	position = "popup." .. battery.name,
	icon = {
		string = "Time remaining:",
		align = "left",
		font = {
			family = fonts.font.text,
			style = fonts.font.style_map["Regular"],
			size = fonts.font.size,
		},
		padding_left = 2,
	},
	label = {
		string = "00:00h",
		align = "right",
		padding_right = 4,
	},
})

-- Battery update function
battery:subscribe({ "routine", "power_source_change", "system_woke" }, function()
	sbar.exec("pmset -g batt", function(batt_info)
		local icon = "!"
		local label = "?"
		local found, _, charge = batt_info:find("(%d+)%%")

		if found then
			charge = tonumber(charge)
			label = charge .. "%"
		end

		local color = colors.green
		local charging, _, _ = batt_info:find("AC Power")

		if charging then
			icon = icons.battery.charging
		else
			if found and charge > 80 then
				icon = icons.battery._100
			elseif found and charge > 60 then
				icon = icons.battery._75
			elseif found and charge > 40 then
				icon = icons.battery._50
			elseif found and charge > 20 then
				icon = icons.battery._25
				color = colors.orange
			else
				icon = icons.battery._0
				color = colors.red
			end
		end

		local lead = ""
		if found and charge < 10 then
			lead = "0"
		end

		battery:set({
			icon = {
				string = icon,
				color = color,
			},
			label = { string = lead .. label },
		})
	end)
end)

local function battery_hide()
	battery:set({ popup = { drawing = false } })
end

-- Guards against a stale auto-close timer dismissing a freshly reopened popup.
local battery_gen = 0

-- Click handler for popup
battery:subscribe("mouse.clicked", function()
	local drawing = battery:query().popup.drawing
	battery:set({ popup = { drawing = "toggle" } })

	if drawing == "off" then
		sbar.exec("pmset -g batt", function(batt_info)
			-- pmset reports "H:MM remaining"; show it as "4h 32m" (or "45m").
			local h, m = batt_info:match(" (%d+):(%d+) remaining")
			local label = "No estimate"
			if h and m then
				h = tonumber(h)
				label = h > 0 and (h .. "h " .. m .. "m") or (tonumber(m) .. "m")
			end
			remaining_time:set({ label = { string = label } })
		end)

		-- SketchyBar's mouse-exit events are unreliable, so guarantee dismissal
		-- with a timer (sbar.exec runs async; the callback fires after sleep).
		battery_gen = battery_gen + 1
		local gen = battery_gen
		sbar.exec("sleep 5", function()
			if battery_gen == gen then
				battery_hide()
			end
		end)
	end
end)

-- Snappy close when the (flaky) hover-exit events do fire.
battery:subscribe("mouse.exited", battery_hide)
battery:subscribe("mouse.exited.global", battery_hide)

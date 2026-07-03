local colors = require("appearance").colors
local sbar = require("sketchybar")
local fonts = require("fonts")

-- CPU temperature (°C) from the shared stats_provider via "system_stats".
local temp = sbar.add("graph", "widgets.temp", 28, {
	position = "right",
	graph = { color = colors.blue },
	background = {
		color = colors.bg4,
		border_color = colors.blue,
		border_width = 2,
		corner_radius = 12,
		height = 24,
	},
	icon = { string = "", padding_left = 12, padding_right = 0 },
	label = {
		string = "…°C",
		font = { family = fonts.font.numbers, style = fonts.font.style_map["Bold"], size = 9.0 },
		padding_left = 6,
		padding_right = 12,
	},
	padding_left = 6, -- extra 3px so the gap to the wifi bracket matches the rest
	padding_right = 3,
})

temp:subscribe("system_stats", function(env)
	local c = tonumber(env.CPU_TEMP) or 0
	temp:push({ math.min(c / 100.0, 1.0) })
	local color = colors.blue
	if c >= 90 then
		color = colors.red
	elseif c >= 75 then
		color = colors.orange
	elseif c >= 60 then
		color = colors.yellow
	end
	temp:set({ graph = { color = color }, label = { string = string.format("%.0f°C", c) } })
end)

temp:subscribe("mouse.clicked", function()
	sbar.exec("open -a 'Activity Monitor'")
end)

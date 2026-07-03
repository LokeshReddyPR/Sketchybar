local colors = require("appearance").colors
local sbar = require("sketchybar")
local fonts = require("fonts")

-- RAM usage from the shared stats_provider (see cpu.lua) via "system_stats".
local ram = sbar.add("graph", "widgets.ram", 28, {
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
		string = "ram …%",
		font = { family = fonts.font.numbers, style = fonts.font.style_map["Bold"], size = 9.0 },
		padding_left = 6,
		padding_right = 12,
	},
	padding_left = 3,
	padding_right = 3,
})

ram:subscribe("system_stats", function(env)
	local used = tonumber(env.RAM_USAGE) or 0
	ram:push({ used / 100.0 })
	local color = colors.blue
	if used >= 90 then
		color = colors.red
	elseif used >= 75 then
		color = colors.yellow
	end
	ram:set({ graph = { color = color }, label = { string = "ram " .. used .. "%" } })
end)

ram:subscribe("mouse.clicked", function()
	sbar.exec("open -a 'Activity Monitor'")
end)

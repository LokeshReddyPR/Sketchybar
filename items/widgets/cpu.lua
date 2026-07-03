local colors = require("appearance").colors
local sbar = require("sketchybar")
local fonts = require("fonts")

-- One provider feeds cpu, ram and temp via the "system_stats" event (every 2s).
sbar.exec(
	"killall stats_provider >/dev/null; killall cpu_load >/dev/null; "
		.. "/opt/homebrew/bin/stats_provider --cpu usage temperature --memory ram_usage --interval 2 --no-units"
)

-- Small sparkline graph on the left, value label on the right, inside a padded
-- pill (like the battery/volume widgets). The item's own background is the pill.
local cpu = sbar.add("graph", "widgets.cpu", 28, {
	position = "right",
	graph = { color = colors.blue },
	background = {
		color = colors.bg4,
		border_color = colors.blue,
		border_width = 2,
		corner_radius = 12,
		height = 24,
	},
	icon = { string = "", padding_left = 12, padding_right = 0 }, -- reserves left padding
	label = {
		string = "cpu …%",
		font = { family = fonts.font.numbers, style = fonts.font.style_map["Bold"], size = 9.0 },
		padding_left = 6,
		padding_right = 12,
	},
	padding_left = 3,
	padding_right = 3,
})

cpu:subscribe("system_stats", function(env)
	local usage = tonumber(env.CPU_USAGE) or 0
	cpu:push({ usage / 100.0 })
	local color = colors.blue
	if usage >= 80 then
		color = colors.red
	elseif usage >= 60 then
		color = colors.orange
	elseif usage >= 30 then
		color = colors.yellow
	end
	cpu:set({ graph = { color = color }, label = { string = "cpu " .. usage .. "%" } })
end)

cpu:subscribe("mouse.clicked", function()
	sbar.exec("open -a 'Activity Monitor'")
end)

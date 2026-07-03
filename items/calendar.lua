local sbar = require("sketchybar")
local fonts = require("fonts")
local colors = require("appearance").colors

local cal = sbar.add("item", {
	background = {
		border_color = colors.magenta,
	},
	icon = {
		color = colors.magenta,
		font = {
			family = fonts.font.text,
			style = fonts.font.style_map["Regular"],
			size = fonts.font.size,
		},
		padding_left = 12,
	},
	label = {
		color = colors.magenta,
		align = "right",
		font = {
			family = fonts.font.text,
			style = fonts.font.style_map["Regular"],
			size = fonts.font.size,
		},
		padding_right = 12,
	},
	position = "right",
	update_freq = 30,
	padding_left = 3,
	padding_right = 3,
})

cal:subscribe({ "forced", "routine", "system_woke" }, function()
	cal:set({ icon = os.date("%a %b %d"), label = os.date("%I:%M %p") })
end)

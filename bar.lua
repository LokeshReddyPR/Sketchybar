local colors = require("appearance").colors
local settings = require("settings")
local sbar = require("sketchybar")

-- Equivalent to the --bar domain
-- TokyoNight Night: floating, transparent, inset & rounded bar
sbar.bar({
	color = colors.bg3, -- transparent; the item pills provide the visible background
	height = settings.height, -- 24
	corner_radius = 12,
	margin = 21,
	y_offset = 11,
	padding_right = 0,
	padding_left = 0,
	sticky = "on",
	topmost = "window",
	blur_radius = 30,
})

local colors = require("appearance").colors
local sbar = require("sketchybar")
local fonts = require("fonts")
local icons = require("icons")

-- network_load fires "network_update" every 2s with env.upload / env.download
-- (formatted strings, e.g. "013KBps"; idle numeric value == 0).
sbar.exec(
	"killall network_load >/dev/null; $CONFIG_DIR/helpers/event_providers/network_load/bin/network_load en0 network_update 2.0"
)

local SPEED_FONT = { family = fonts.font.numbers, style = fonts.font.style_map["Bold"], size = 9.0 }
local ARROW_FONT = { style = fonts.font.style_map["Bold"], size = 9.0 }

-- Upload (upper line). width=0 so it reserves no horizontal space and the
-- download item below overlaps it; y_offset stacks them. Added FIRST.
local wifi_up = sbar.add("item", "widgets.wifi.up", {
	position = "right",
	background = { drawing = false },
	width = 0,
	y_offset = -5,
	icon = { string = icons.wifi.upload, font = ARROW_FONT, color = colors.red, padding_left = 12, padding_right = 3 },
	label = { string = "0 Bps", font = SPEED_FONT, color = colors.red, padding_right = 12 },
})

-- Download (lower line). Normal width; defines the pill slot. Added SECOND.
local wifi_down = sbar.add("item", "widgets.wifi.down", {
	position = "right",
	background = { drawing = false },
	y_offset = 5,
	icon = { string = icons.wifi.download, font = ARROW_FONT, color = colors.blue, padding_left = 12, padding_right = 3 },
	label = { string = "0 Bps", font = SPEED_FONT, color = colors.blue, padding_right = 12 },
})

local function idle(s)
	return (tonumber((s or ""):match("[%d%.]+")) or 0) == 0
end

wifi_down:subscribe("network_update", function(env)
	local down_color = idle(env.download) and colors.grey or colors.blue
	local up_color = idle(env.upload) and colors.grey or colors.red
	wifi_down:set({ icon = { color = down_color }, label = { string = env.download, color = down_color } })
	wifi_up:set({ icon = { color = up_color }, label = { string = env.upload, color = up_color } })
end)

local function open_settings()
	sbar.exec("open 'x-apple.systempreferences:com.apple.wifi-settings-extension'")
end
wifi_down:subscribe("mouse.clicked", open_settings)
wifi_up:subscribe("mouse.clicked", open_settings)

-- Pill (navy background + blue border) around the stacked speeds
sbar.add("bracket", "widgets.wifi.bracket", { wifi_up.name, wifi_down.name }, {
	background = {
		color = colors.bg4,
		border_color = colors.blue,
		border_width = 2,
		corner_radius = 12,
	},
})

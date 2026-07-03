local settings = require("settings")
local sbar = require("sketchybar")
local fonts = require("fonts")

local M = {}

M.colors = {
	-- TokyoNight Night palette
	default = 0x80a9b1d6,
	black = 0xff24283b,
	white = 0xffa9b1d6,
	red = 0xfff7768e,
	red_bright = 0xfff7768e,
	green = 0xff9ece6a,
	blue = 0xff7aa2f7,
	blue_bright = 0xff7dcfff,
	yellow = 0xffe0af68,
	orange = 0xffff9e64,
	magenta = 0xffbb9af7,
	grey = 0xff565f89,
	transparent = 0x00000000,

	bar = {
		bg = 0x00000000,
		border = 0xff7aa2f7,
	},

	popup = {
		bg = 0xff1a1b26,
		border = 0xff7aa2f7,
	},

	bg1 = 0xff1a1b26,
	bg2 = 0xff24283b,
	bg3 = 0x00000000, -- transparent bar background
	bg4 = 0xff1a1b26, -- default item pill background (navy)

	accent = 0xff7aa2f7,
	accent_bright = 0xff1a1b26, -- workspace pill background (navy)
	accent_tbright = 0x331a1b26,

	spotify_green = 0xe040a02b,

	-- Catppuccin Mocha Theme
	mocha = {
		rosewater = 0xfff5e0dc,
		flamingo = 0xfff2cdcd,
		pink = 0xfff5c2e7,
		mauve = 0xffcba6f7,
		red = 0xfff38ba8,
		maroon = 0xffeba0ac,
		peach = 0xfffab387,
		yellow = 0xfff9e2af,
		green = 0xffa6e3a1,
		teal = 0xff94e2d5,
		sky = 0xff89dceb,
		sapphire = 0xff74c7ec,
		blue = 0xff89b4fa,
		lavender = 0xffb4befe,
		text = 0xffcdd6f4,
		base = 0xff1e1e2e,
		mantle = 0xff181825,
		crust = 0xff11111b,
	},

	-- Catppuccin Macchiato Theme
	macchiato = {
		rosewater = 0xfff4dbd6,
		flamingo = 0xfff0c6c6,
		pink = 0xfff5a97f,
		mauve = 0xffc6a0f6,
		red = 0xffed8796,
		maroon = 0xffee99a0,
		peach = 0xfff5a97f,
		yellow = 0xffeed49f,
		green = 0xffa6da95,
		teal = 0xff8bd5ca,
		sky = 0xff91d7e3,
		sapphire = 0xff7dc4e4,
		blue = 0xff8aadf4,
		lavender = 0xffb7bdf8,
		text = 0xffcad3f5,
		subtext1 = 0xffb8c0e0,
		subtext0 = 0xffa5adcb,
		overlay2 = 0xff939ab7,
		overlay1 = 0xff8087a2,
		overlay0 = 0xff6e738d,
		surface2 = 0xff5b6078,
		surface1 = 0xff494d64,
		surface0 = 0xff363a4f,
		base = 0xff24273a,
		mantle = 0xff1e2030,
		crust = 0xff181926,
	},

	-- Catppuccin Latte Theme
	latte = {
		rosewater = 0xffdc8a78,
		flamingo = 0xffdd7878,
		pink = 0xffea76cb,
		mauve = 0xff8839ef,
		red = 0xffd20f39,
		maroon = 0xffe64553,
		peach = 0xfffe640b,
		yellow = 0xffdf8e1d,
		green = 0xff40a02b,
		teal = 0xff179299,
		sky = 0xff04a5e5,
		sapphire = 0xff209fb5,
		blue = 0xff1e66f5,
		lavender = 0xff7287fd,
		text = 0xff4c4f69,
		base = 0xffeff1f5,
		mantle = 0xffe6e9ef,
		crust = 0xffdce0e8,
	},

	-- TokyoNight Night Theme (active)
	tokyonight = {
		rosewater = 0xffe0af68,
		flamingo = 0xffff9e64,
		pink = 0xffbb9af7,
		mauve = 0xffbb9af7,
		red = 0xfff7768e,
		maroon = 0xfff7768e,
		peach = 0xffff9e64,
		yellow = 0xffe0af68,
		green = 0xff9ece6a,
		teal = 0xff73daca,
		sky = 0xff7dcfff,
		sapphire = 0xff7dcfff,
		blue = 0xff7aa2f7,
		lavender = 0xff9d7cd8,
		text = 0xffc0caf5,
		subtext1 = 0xff9aa5ce,
		subtext0 = 0xff737aa2,
		overlay2 = 0xff565f89,
		overlay1 = 0xff545c7e,
		overlay0 = 0xff414868,
		surface2 = 0xff3b4261,
		surface1 = 0xff292e42,
		surface0 = 0xff24283b,
		base = 0xff1a1b26,
		mantle = 0xff16161e,
		crust = 0xff13131a,
	},

	-- Utility Function

	with_alpha = function(color, alpha)
		if alpha > 1.0 or alpha < 0.0 then
			return color
		end
		return (color & 0x00ffffff) | (math.floor(alpha * 255.0) * 0x1000000)
	end,
}

-- Set the active theme
M.colors.active = M.colors.tokyonight

-- Holds specific styles for different components, like workspaces.
-- These are applied manually in their respective files.
M.styles = {
	-- Styles for the workspace items created in items/spaces.lua
	workspace = {
		background = {
			color = M.colors.accent_bright,
			border_color = M.colors.blue,
			border_width = 2,
			corner_radius = 12,
			drawing = true,
		},
		icon = {
			color = M.colors.blue,
			highlight_color = M.colors.red,
			font = {
				family = fonts.font.text,
				style = fonts.font.style_map["Bold"],
				size = fonts.font.size,
			},
			padding_left = 12,
			padding_right = 2,
		},
		label = {
			color = M.colors.blue,
			highlight_color = M.colors.red,
			font = "sketchybar-app-font:Regular:16.0",
			padding_left = 2,
			padding_right = 12,
			y_offset = -1,
		},
	},
}

-- Sets the global default properties for all items in sketchybar.
-- Individual items can override these.
sbar.default({
	-- Default background properties for the main bar
	background = {
		border_color = M.colors.blue,
		border_width = 2,
		color = M.colors.bg4, -- navy item pill (TokyoNight bg)
		corner_radius = 12,
		height = 24,
		image = {
			corner_radius = 9,
			border_color = M.colors.white,
			border_width = 1,
		},
	},
	-- Default properties for all icons (e.g., apple, calendar, widgets)
	icon = {
		font = {
			family = fonts.font_icon.text,
			style = fonts.font_icon.style_map["Bold"],
			size = fonts.font_icon.size,
		},
		color = M.colors.blue,
		highlight_color = M.colors.red,
		padding_left = 0,
		padding_right = 0,
	},
	-- Default properties for all text labels (e.g., volume, battery, time)
	label = {
		font = {
			family = fonts.font.text,
			style = fonts.font.style_map["Regular"],
			size = fonts.font.size,
		},
		color = M.colors.blue,
		padding_left = settings.paddings,
		padding_right = settings.paddings,
	},
	-- Default properties for popup menus
	popup = {
		align = "center",
		background = {
			border_width = 0,
			corner_radius = 6,
			color = M.colors.bg1,
			shadow = { drawing = true },
		},
		blur_radius = 50,
		y_offset = 5,
	},
	padding_left = 3,
	padding_right = 3,
	scroll_texts = true,
	updates = "on",
})

return M

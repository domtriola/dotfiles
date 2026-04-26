local hyper = { "cmd", "alt", "ctrl" }

-- ControlEscape (remaps ctrl to escape on quick press)
hs.loadSpoon("ControlEscape"):start()

-- Cherry (Pomodoro timer)
hs.loadSpoon("Cherry")
spoon.Cherry.duration = 25 -- minutes per session
spoon.Cherry:bindHotkeys({}) -- uses default: cmd+ctrl+alt+C

-- AppWindowSwitcher (switch between windows of specific apps)
hs
	.loadSpoon("AppWindowSwitcher")
	-- :setLogLevel("debug") -- uncomment for console debug log
	:bindHotkeys({
		["Obsidian"] = { hyper, "O" }, -- O for Obsidian
		["Ghostty"] = { hyper, "T" }, -- T for terminal
		[{
			"com.apple.Safari",
			"com.google.Chrome",
			"org.mozilla.firefox",
			"com.brave.Browser",
		}] = { hyper, "B" }, -- B for browser
	})

-- WindowHalfsAndThirds (window snapping)
hs.loadSpoon("WindowHalfsAndThirds")
spoon.WindowHalfsAndThirds:bindHotkeys({
	left_half = { hyper, "H" },
	right_half = { hyper, "L" },
	top_half = { hyper, "K" },
	bottom_half = { hyper, "J" },
	max = { hyper, "Up" },
	third_left = { hyper, "Left" },
	third_right = { hyper, "Right" },
	center = { hyper, "Down" },
})

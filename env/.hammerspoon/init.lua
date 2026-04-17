local hyper = {"cmd", "alt", "ctrl"}

-- Cherry (Pomodoro timer)
hs.loadSpoon("Cherry")
spoon.Cherry.duration = 25          -- minutes per session
spoon.Cherry:bindHotkeys({})        -- uses default: cmd+ctrl+alt+C

-- AppWindowSwitcher (switch between windows of specific apps)
hs.loadSpoon("AppWindowSwitcher")
  -- :setLogLevel("debug") -- uncomment for console debug log
  :bindHotkeys({
    ["Obsidian"]                  = {hyper, "1"},
    ["iTerm"]                     = {hyper, "2"},
    [{"com.apple.Safari",
      "com.google.Chrome",
      "com.kagi.kagimacOS",
      "com.microsoft.edgemac",
      "org.mozilla.firefox"}]     = {hyper, "3"},
    })

-- WindowHalfsAndThirds (window snapping)
hs.loadSpoon("WindowHalfsAndThirds")
spoon.WindowHalfsAndThirds:bindHotkeys({
  left_half    = {hyper, "H"},
  right_half   = {hyper, "L"},
  top_half     = {hyper, "K"},
  bottom_half  = {hyper, "J"},
  top_left     = {hyper, "Y"},
  top_right    = {hyper, "U"},
  bottom_left  = {hyper, "B"},
  bottom_right = {hyper, "N"},
  max          = {hyper, "F"}
});

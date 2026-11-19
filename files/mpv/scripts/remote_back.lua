-- remote_back.lua
-- The remote's Back button (GO_BACK, bound in input.conf). If mpv's menu
-- or a track list is open, it closes that. Otherwise it leaves the player
-- (back to Stremio etc.) and remembers the position. Without this, Back
-- quit straight through an open menu, and the menu itself only closed on
-- Esc, which the remote side doesn't have.

local mp = require 'mp'

mp.add_key_binding(nil, "back", function()
    -- set by mpv's built-in console.lua, which also draws the select menus
    if mp.get_property_native("user-data/mpv/console/open") then
        mp.commandv("script-message-to", "console", "disable")
    else
        mp.command("quit-watch-later")
    end
end)

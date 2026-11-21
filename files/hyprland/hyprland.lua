-- HTPC Hyprland config: the static half.
-- modules/desktop/hyprland.nix appends the generated half (monitor,
-- environment, fullscreen rules, autostart, extraConfig) and installs the
-- result as /etc/htpc/hyprland.lua, which Hyprland is started with
-- (`start-hyprland -- -c /etc/htpc/hyprland.lua`). ~/.config/hypr is not read.
--
-- Kept barebones on purpose: the TV UI is going to be quickshell, so this
-- only has to be a sane, quiet compositor driven by a remote.
-- Lua API: https://wiki.hypr.land/Configuring/Start/

-----------------------
---- LOOK AND FEEL ----
-----------------------

hl.config({
    general = {
        -- monocle: every tiled app fills the screen and the focused one is
        -- on top (SUPER+TAB cycles). No side-by-side splits on a TV.
        gaps_in     = 0,
        gaps_out    = 0,
        border_size = 0,
        layout      = "monocle",
        allow_tearing = false,
    },

    -- With the TV at scale 2, X11 apps (Steam) would otherwise be upscaled
    -- and blurry. They render at native 4K instead and scale their own UI
    -- (STEAM_FORCE_DESKTOPUI_SCALING, set in modules/desktop/hyprland.nix).
    xwayland = {
        force_zero_scaling = true,
    },

    decoration = {
        rounding = 0,
        shadow   = { enabled = false },
        blur     = { enabled = true, size = 6, passes = 2 }, -- for quickshell overlays later
    },

    animations = { enabled = true },  -- calm curves below, nothing bouncy

    misc = {
        disable_hyprland_logo    = true,
        disable_splash_rendering = true,
        force_default_wallpaper  = 0,
        background_color         = "rgb(000000)",
        enable_anr_dialog        = false,  -- no "app not responding" popups needing a mouse
        focus_on_activate        = true,   -- apps raised by a handoff (mpv) get focus
        -- only one window per workspace can be fullscreen: when mpv closes,
        -- hand fullscreen back to the app underneath (Stremio), or it comes
        -- back windowed with its title bar
        exit_window_retains_fullscreen = 1,
    },

    cursor = {
        inactive_timeout = 3,  -- hide the air-mouse pointer when idle
    },

    render = {
        direct_scanout = true,  -- fullscreen video skips compositing
        -- HDR: the desktop stays SDR, and the TV switches to HDR while a
        -- fullscreen app shows HDR content (mpv reports it through
        -- target-colorspace-hint). Replaces the old kscreen-doctor toggle.
        cm_auto_hdr = 1,
    },
})

-- Calm, short animations: plain ease-out, small pop-in, fades between
-- workspaces. Hyprland's defaults overshoot and slide, which looks frantic
-- on a big screen.
hl.curve("calm", { type = "bezier", points = { {0.25, 0.1}, {0.25, 1.0} } })
hl.animation({ leaf = "windows",     enabled = true, speed = 4, bezier = "calm", style = "popin 95%" })
hl.animation({ leaf = "windowsOut",  enabled = true, speed = 3, bezier = "calm", style = "popin 95%" })
hl.animation({ leaf = "windowsMove", enabled = true, speed = 4, bezier = "calm" })
hl.animation({ leaf = "fade",        enabled = true, speed = 4, bezier = "calm" })
hl.animation({ leaf = "layers",      enabled = true, speed = 3, bezier = "calm", style = "fade" })
hl.animation({ leaf = "workspaces",  enabled = true, speed = 4, bezier = "calm", style = "fade" })

---------------
---- INPUT ----
---------------

hl.config({
    input = {
        kb_layout    = "us",
        follow_mouse = 1,
        sensitivity  = 0,
    },
})

---------------------
---- KEYBINDINGS ----
---------------------
-- Keyboard binds for maintenance; the remote's own keys (arrows, OK, Back,
-- Home) go straight to the focused app. Home gets the launcher until
-- quickshell replaces it.

local mainMod = "SUPER"

hl.bind(mainMod .. " + RETURN",    hl.dsp.exec_cmd("foot"))
hl.bind(mainMod .. " + SHIFT + Q", hl.dsp.window.close())
hl.bind(mainMod .. " + F",         hl.dsp.window.fullscreen())
hl.bind(mainMod .. " + TAB",       hl.dsp.window.cycle_next())  -- next app (monocle shows one at a time)
hl.bind(mainMod .. " + SPACE",     hl.dsp.exec_cmd("fuzzel"))
hl.bind("XF86HomePage",            hl.dsp.exec_cmd("fuzzel"))

hl.bind(mainMod .. " + left",  hl.dsp.focus({ direction = "left" }))
hl.bind(mainMod .. " + right", hl.dsp.focus({ direction = "right" }))
hl.bind(mainMod .. " + up",    hl.dsp.focus({ direction = "up" }))
hl.bind(mainMod .. " + down",  hl.dsp.focus({ direction = "down" }))

for i = 1, 10 do
    local key = i % 10
    hl.bind(mainMod .. " + " .. key,         hl.dsp.focus({ workspace = i }))
    hl.bind(mainMod .. " + SHIFT + " .. key, hl.dsp.window.move({ workspace = i }))
end

-- Volume and media keys (remote + keyboard). playerctl reaches anything with MPRIS (mpv via mpris script, browsers).
hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("wpctl set-volume -l 1.0 @DEFAULT_AUDIO_SINK@ 5%+"), { locked = true, repeating = true })
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"), { locked = true, repeating = true })
hl.bind("XF86AudioMute",        hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"), { locked = true })
hl.bind("XF86AudioPlay",        hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPrev",        hl.dsp.exec_cmd("playerctl previous"),   { locked = true })
hl.bind("XF86AudioNext",        hl.dsp.exec_cmd("playerctl next"),       { locked = true })

--------------------------------
---- WINDOWS AND WORKSPACES ----
--------------------------------

hl.window_rule({
    name  = "suppress-maximize-events",
    match = { class = ".*" },
    suppress_event = "maximize",
})

hl.window_rule({ name = "modal-float", match = { modal = true }, float = true, center = true })

-- Steam: everything except the main window floats (friends, settings, login...)
hl.window_rule({ name = "steam-popups", match = { class = "^steam$", title = "negative:^Steam$" }, float = true })

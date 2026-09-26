-- auto_upscaler.lua
-- Profile switching by resolution / aspect / HDR, with KDE SDR<->HDR automation.
-- Press 'a' to toggle Anime/Live-Action.
--
-- HopperRender is DISABLED here: non-CRT (HDR) content uses mpv's built-in
-- interpolation instead. CRT/SDR content uses the CRT profiles' own pipeline.
--
-- CRT_ALL_SDR = false : CRT only for 4:3 (or 5:4) SDR content
-- CRT_ALL_SDR = true  : CRT for ALL SDR content

local mp = require 'mp'

local last_profile = nil
local manual_anime_override = false

-----------------------------------------------------
-- CONFIG
-----------------------------------------------------
local CRT_ALL_SDR          = false         -- CRT for all SDR (HDR detection confirmed working)

-- mpv built-in interpolation for NON-CRT (HDR) content:
--   "mitchell"   : blends -> smoother motion, but softer / can ghost on fast motion
--   "oversample" : crisp, preserves original 24fps cadence (minimal smoothing)
-- Or set NONCRT_INTERP = false to turn interpolation off entirely (24->120 as clean 5:5).
local NONCRT_INTERP        = true
local NONCRT_TSCALE        = "oversample"

local DISPLAY_OUTPUT       = "HDMI-A-1"   -- from `kscreen-doctor -o`
local DESKTOP_HDR_DEFAULT  = true         -- desktop's normal HDR state, restored on exit
local MANAGE_DISPLAY_HDR   = true         -- master switch for the KDE HDR/WCG toggle

local display_is_crt = nil

local cfg = { hdr_suffix = "_hdr", use_hdr_profiles = false }

-----------------------------------------------------
-- HELPERS
-----------------------------------------------------

-- transfer/gamma tag from the decoder params first, falling back to output params.
-- HDR is mandatory-signalled as pq or hlg; anything else, including unknown, is SDR.
local function transfer_tag()
    return mp.get_property_native("video-dec-params/gamma")
        or mp.get_property_native("video-params/gamma")
end

local function is_hdr()
    local trc = transfer_tag()
    return trc == "pq" or trc == "hlg"
end

local function is_youtube()
    local path = mp.get_property("path") or ""
    return string.find(path, "youtube%.com") ~= nil
        or string.find(path, "youtu%.be") ~= nil
end

-- Width for widescreen, height for 4:3
local function get_res_tier(w, h)
    if w == 0 or h == 0 then return "native" end
    local ar = w / h
    local is_43 = ar <= 1.48
    if is_43 then
        if h <= 480 then return "480"
        elseif h <= 720 then return "720"
        elseif h <= 1080 then return "1080"
        end
    else
        if w <= 1024 then return "480"
        elseif w <= 1600 then return "720"
        elseif w <= 2800 then return "1080"
        end
    end
    return "native"
end

-----------------------------------------------------
-- DISPLAY (COMPOSITOR) AUTOMATION
-----------------------------------------------------
local function kscreen_hdr(enable, blocking)
    local v = enable and "enable" or "disable"
    local t = {
        name = "subprocess", playback_only = false,
        capture_stdout = true, capture_stderr = true,
        args = {
            "kscreen-doctor",
            "output." .. DISPLAY_OUTPUT .. ".hdr." .. v,
            "output." .. DISPLAY_OUTPUT .. ".wcg." .. v,
        },
    }
    if blocking then mp.command_native(t) else mp.command_native_async(t, function() end) end
end

local function set_display_for_crt(want_crt, blocking)
    if not MANAGE_DISPLAY_HDR then return end
    if want_crt == display_is_crt then return end
    if want_crt then kscreen_hdr(false, blocking)
    else kscreen_hdr(DESKTOP_HDR_DEFAULT, blocking) end
    display_is_crt = want_crt
end

-----------------------------------------------------
-- PROFILE APPLICATION
-----------------------------------------------------
local function apply_profile(use_anime)
    local w = mp.get_property_number("video-params/w", 0)
    local h = mp.get_property_number("video-params/h", 0)
    if w == 0 or h == 0 then return end

    local res_tier = get_res_tier(w, h)
    local use_crt  = false

    if not is_hdr() then
        if CRT_ALL_SDR then
            use_crt = true
        else
            local ar = w / h
            if ar <= 1.48 then use_crt = true end   -- 4:3 / 5:4 only
        end
    end

    -- KDE HDR follows CRT state
    set_display_for_crt(use_crt, false)

    -- HopperRender disabled: strip it if anything ever added it (harmless if absent)
    mp.commandv("vf", "remove", "HopperRender")

    -- Build + apply the profile
    local prefix = (is_youtube() and not use_anime) and "youtube_" or ""
    local type_str = use_anime and "anime_" or "upscale_"
    local crt_str  = use_crt and "_crt" or ""
    local prof = prefix .. type_str .. res_tier .. crt_str
    if cfg.use_hdr_profiles and is_hdr() and not use_crt then
        prof = prof .. cfg.hdr_suffix
    end

    if prof ~= last_profile then
        mp.commandv("apply-profile", prof)
        last_profile = prof
    end

    -- Interpolation: CRT profiles own theirs (beam shader). For non-CRT, apply
    -- mpv's built-in interpolation here, AFTER the profile so it isn't overridden.
    local interp_msg
    if use_crt then
        interp_msg = "Interp: CRT beam"
    elseif NONCRT_INTERP then
        mp.set_property("interpolation", "yes")
        mp.set_property("video-sync", "display-resample")
        mp.set_property("tscale", NONCRT_TSCALE)
        interp_msg = "Interp: mpv builtin (" .. NONCRT_TSCALE .. ")"
    else
        mp.set_property("interpolation", "no")
        mp.set_property("video-sync", "audio")
        interp_msg = "Interp: off"
    end

    local type_msg = use_anime and "Anime" or "Live-Action"
    local crt_msg  = use_crt and " (SDR/CRT)" or (is_hdr() and " (HDR)" or " (SDR)")
    mp.osd_message(string.format("Profile: %s\nType: %s%s\n%s   [trc=%s]",
        prof, type_msg, crt_msg, interp_msg, tostring(transfer_tag())), 3.0)
end

-----------------------------------------------------
-- TOGGLE + EVENT HOOKS
-----------------------------------------------------
local function toggle_anime()
    manual_anime_override = not manual_anime_override
    apply_profile(manual_anime_override)
end
mp.add_key_binding("a", "toggle-anime", toggle_anime)

mp.register_event("file-loaded", function()
    last_profile = nil
    manual_anime_override = false
    apply_profile(false)
    -- catch color tags that populate a beat after load
    mp.add_timeout(0.5, function() apply_profile(manual_anime_override) end)
end)

mp.observe_property("video-params/h", "native", function()
    apply_profile(manual_anime_override)
end)

mp.register_event("shutdown", function()
    if display_is_crt then set_display_for_crt(false, true) end
end)

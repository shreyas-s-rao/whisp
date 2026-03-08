-- Whisp — loaded via dofile() from ~/.hammerspoon/init.lua
-- Config (keys, sox path) is written by install.sh into ~/.whisp/config.lua

local cfg = dofile(os.getenv("HOME") .. "/.whisp/config.lua")

local recording = false
local rec_task  = nil

-- ── recording ─────────────────────────────────────────────────────────────────

local function start_recording()
    if recording then return end
    recording = true
    hs.alert.show("🎙 Recording…")
    rec_task = hs.task.new(cfg.sox_rec, nil, {"/tmp/dict.wav"})
    rec_task:start()
end

local function stop_recording()
    if not recording then return end
    recording = false
    hs.alert.show("⏳ Processing…")
    if rec_task then
        rec_task:terminate()
        rec_task = nil
    end
    local home = os.getenv("HOME")
    hs.task.new("/bin/bash", nil, {"-c", home .. "/.whisp/transcribe.sh"}):start()
end

hs.hotkey.bind({}, cfg.record, start_recording, stop_recording)

-- ── learning ──────────────────────────────────────────────────────────────────

hs.hotkey.bind({}, cfg.learn, function()
    local original = hs.pasteboard.getContents()

    -- copy the currently selected text
    hs.eventtap.keyStroke({"cmd"}, "c")

    hs.timer.doAfter(0.15, function()
        local selected = hs.pasteboard.getContents()

        if selected and selected ~= "" then
            local home    = os.getenv("HOME")
            local escaped = selected:gsub('"', '\\"')
            local cmd     = 'echo "' .. escaped .. '" | '
                         .. home .. '/.whisp/venv/bin/python '
                         .. home .. '/.whisp/learn.py'
            hs.execute(cmd)
            hs.alert.show("✅ Correction learned")
        else
            hs.alert.show("⚠️ No text selected")
        end

        -- restore clipboard to what it was before
        hs.pasteboard.setContents(original)
    end)
end)

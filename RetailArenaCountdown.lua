--[[
RetailArenaCountdown, for the 3.3.5a client (Wrath of the Lich King).

The arena countdown as in the modern game: big numbers in the middle of the
screen from 60 seconds down, a sound at 10 and on every second from 9 to 1,
and your faction's crest with a closing sound when the gates open. It works
on its own: Gladdy is not needed. If Gladdy is loaded, its own countdown is
switched off so the two never show at once; Gladdy's saved settings are not
changed.

Built to cost as little as possible in the game:
  - The frame and its textures are only created the first time a countdown
    is shown: never entering an arena means they never exist.
  - The clock only runs while a countdown is on screen, about a minute per
    match; the rest of the time the addon does nothing at all.
  - Only the player's language of the arena messages is kept in memory.
  - Image paths are built once. Nothing global except the saved settings and
    the slash command.

Based on the arena countdown module of Gladdy (XiconQoo, DnB_Junkee, Knall,
Tsoukie), GPL-2.0. The number and crest images come from Gladdy; the sounds
are Blizzard's.

/racd          status and commands
/racd test     a 15-second countdown, to see it outside the arena
/racd size N   size in pixels, 64 to 512 (256 by default)
/racd on, /racd off
]]

local ADDON, ns = ...

local MEDIA = "Interface\\AddOns\\" .. ADDON .. "\\"
local SOUND_TICK = MEDIA .. "Sounds\\UI_BattlegroundCountdown_Timer.ogg"
local SOUND_END = MEDIA .. "Sounds\\UI_BattlegroundCountdown_End.ogg"
local TEST_SECONDS = 15
local floor = math.floor
local PlaySoundFile = PlaySoundFile

-- Every image path, built once: digits 0-9 and the two crests.
local IMAGE = {}
for digit = 0, 9 do
    IMAGE[digit] = MEDIA .. "Images\\" .. digit
end
IMAGE.Alliance = MEDIA .. "Images\\Alliance"
IMAGE.Horde = MEDIA .. "Images\\Horde"

ns.DEFAULTS = { enabled = true, size = 256, strata = "HIGH", level = 50 }

local events = CreateFrame("Frame")
ns.events = events

-- Display ------------------------------------------------------------------

--- Size, layer and position, from the saved settings.
function ns.ApplyLayout()
    local frame = ns.frame
    if not frame then
        return -- not created yet: it will use the settings when it is
    end
    local size = ns.db.size
    local offset = size / 8 + size / 16
    frame:SetFrameStrata(ns.db.strata)
    frame:SetFrameLevel(ns.db.level)
    frame:SetWidth(size)
    frame:SetHeight(size)
    frame:ClearAllPoints()
    frame:SetPoint("CENTER", UIParent, "CENTER", 0, 128)
    for _, texture in ipairs({ ns.tens, ns.ones, ns.single }) do
        texture:SetWidth(size)
        texture:SetHeight(size)
        texture:ClearAllPoints()
    end
    ns.tens:SetPoint("CENTER", frame, "CENTER", -offset, 0)
    ns.ones:SetPoint("CENTER", frame, "CENTER", offset, 0)
    ns.single:SetPoint("CENTER", frame, "CENTER", 0, 0)
end

--- The frame in the middle of the screen, created the first time it is
--- needed: two textures for two-digit numbers and one for a single digit or
--- the crest.
local function display()
    if not ns.frame then
        local frame = CreateFrame("Frame", nil, UIParent)
        frame:EnableMouse(false)
        frame:Hide()
        ns.frame = frame
        ns.tens = frame:CreateTexture(nil, "OVERLAY")
        ns.ones = frame:CreateTexture(nil, "OVERLAY")
        ns.single = frame:CreateTexture(nil, "OVERLAY")
        ns.ApplyLayout()
    end
    return ns.frame
end

function ns.HideAll()
    if ns.frame then
        ns.frame:Hide()
    end
end

-- Clock --------------------------------------------------------------------

-- A tick every second while a countdown is on screen. 3.3.5a has no
-- C_Timer, so it is an OnUpdate script that adds up the time between frames;
-- the frame is hidden, so the script does not run, the rest of the time.
local clock = CreateFrame("Frame")
clock:Hide()
local sinceLastTick = 0
clock:SetScript("OnUpdate", function(_, elapsed)
    sinceLastTick = sinceLastTick + elapsed
    if sinceLastTick >= 1 then
        sinceLastTick = sinceLastTick - 1
        ns.Tick()
    end
end)
ns.clock = clock

local function startClock()
    if not clock:IsShown() then
        sinceLastTick = 0
        clock:Show()
    end
end

--- One second of the countdown: draws the number and plays its sound.
function ns.Tick()
    local count = ns.countdown
    if not ns.db.enabled or not count or count < 0 or count > 60 then
        -- Turned off, or the crest has been shown: put everything back.
        ns.Reset()
        return
    end

    local frame = display()
    if count >= 10 then
        -- Two digits. The tens are rounded down: 45 / 10 is 4.5 in Lua, and
        -- an image called "4.5" does not exist.
        ns.single:Hide()
        ns.tens:SetTexture(IMAGE[floor(count / 10)])
        ns.ones:SetTexture(IMAGE[count % 10])
        ns.tens:Show()
        ns.ones:Show()
        frame:SetScale(0.7)
        if count == 10 then
            PlaySoundFile(SOUND_TICK)
        end
    else
        -- One digit, or the crest when the gates open.
        ns.tens:Hide()
        ns.ones:Hide()
        local image = IMAGE[count > 0 and count or UnitFactionGroup("player")]
        if image then
            ns.single:SetTexture(image)
            ns.single:Show()
        else
            ns.single:Hide()
        end
        frame:SetScale(1.0)
        PlaySoundFile(count == 0 and SOUND_END or SOUND_TICK)
    end
    frame:Show()
    ns.countdown = count - 1
end

-- Arena --------------------------------------------------------------------

--- A system message during the arena preparation: if it is one of the
--- countdown messages, the countdown jumps to its number of seconds.
function ns.OnArenaMessage(message)
    if not message or ns.countdown == 0 then
        return -- "The battle has begun" again while the crest is up
    end
    for seconds, text in pairs(ns.messages) do
        if message:find(text, 1, true) then
            ns.countdown = seconds
            startClock()
            return
        end
    end
end

-- The boss emote frame repeats the arena messages in big letters. It is
-- silenced in the arena, and only given back if it was this addon that
-- silenced it.
local function silenceBossEmotes()
    if not RaidBossEmoteFrame then
        return
    end
    -- If this client cannot tell, the frame is listening: that is the default.
    local listening = not RaidBossEmoteFrame.IsEventRegistered
        or RaidBossEmoteFrame:IsEventRegistered("CHAT_MSG_RAID_BOSS_EMOTE")
    if listening then
        RaidBossEmoteFrame:UnregisterEvent("CHAT_MSG_RAID_BOSS_EMOTE")
        ns.silencedEmotes = true
    end
end

local function restoreBossEmotes()
    if ns.silencedEmotes then
        RaidBossEmoteFrame:RegisterEvent("CHAT_MSG_RAID_BOSS_EMOTE")
        ns.silencedEmotes = false
    end
end

--- Stops the countdown and puts everything back.
function ns.Reset()
    clock:Hide()
    ns.countdown = nil
    events:UnregisterEvent("CHAT_MSG_BG_SYSTEM_NEUTRAL")
    events:UnregisterEvent("ARENA_OPPONENT_UPDATE")
    restoreBossEmotes()
    ns.HideAll()
end

--- Called on every loading screen and zone change: listens for the arena
--- messages only inside an arena.
function ns.UpdateArenaState()
    local _, kind = IsInInstance()
    if kind == "arena" then
        if not ns.inArena then
            ns.inArena = true
            if ns.db.enabled then
                events:RegisterEvent("CHAT_MSG_BG_SYSTEM_NEUTRAL")
                events:RegisterEvent("ARENA_OPPONENT_UPDATE")
                silenceBossEmotes()
            end
        end
    elseif ns.inArena then
        ns.inArena = false
        ns.Reset()
    end
end

-- Gladdy -------------------------------------------------------------------

--- If Gladdy is loaded, its countdown never starts: the two methods that
--- start it are replaced, in memory only, by ones that do nothing. Gladdy
--- looks its methods up by name each time, so this is enough, and its saved
--- settings stay as the player left them. Returns true if it did it.
function ns.SilenceGladdy()
    local Gladdy = LibStub and LibStub("Gladdy", true)
    local module = Gladdy and Gladdy.modules and Gladdy.modules["Arena Countdown"]
    if not module or module.silencedByRetailArenaCountdown then
        return false
    end
    local nothing = function() end
    module.JOINED_ARENA = nothing
    module.TestOnce = nothing
    module.silencedByRetailArenaCountdown = true
    return true
end

-- Commands -----------------------------------------------------------------

local function say(text)
    print("|cffffd100RetailArenaCountdown|r: " .. text)
end

function ns.Command(input)
    local command, value = (input or ""):lower():match("^%s*(%S*)%s*(.-)%s*$")
    if command == "test" then
        ns.countdown = TEST_SECONDS
        startClock()
        say("test countdown started.")
    elseif command == "size" then
        local size = tonumber(value)
        if size and size >= 64 and size <= 512 then
            ns.db.size = floor(size)
            ns.ApplyLayout()
            say("size set to " .. ns.db.size .. ".")
        else
            say("the size goes from 64 to 512, for example /racd size 256.")
        end
    elseif command == "on" or command == "off" then
        ns.db.enabled = command == "on"
        if not ns.db.enabled then
            ns.Reset()
        end
        say(ns.db.enabled and "on." or "off.")
    else
        say((ns.db.enabled and "on" or "off") .. ", size " .. ns.db.size .. ".")
        say("/racd test, /racd size 64-512, /racd on, /racd off")
    end
end

SLASH_RETAILARENACOUNTDOWN1 = "/racd"
SLASH_RETAILARENACOUNTDOWN2 = "/retailarenacountdown"
SlashCmdList.RETAILARENACOUNTDOWN = ns.Command

-- Events -------------------------------------------------------------------

events:SetScript("OnEvent", function(self, event, arg1, arg2)
    if event == "CHAT_MSG_BG_SYSTEM_NEUTRAL" then
        ns.OnArenaMessage(arg1)
    elseif event == "ARENA_OPPONENT_UPDATE" then
        -- An enemy seen while time is left means the match is already on.
        if arg2 == "seen" and ns.countdown and ns.countdown > 0 then
            ns.Reset()
        end
    elseif event == "ADDON_LOADED" then
        if arg1 ~= ADDON then
            return
        end
        self:UnregisterEvent(event)
        RetailArenaCountdownDB = RetailArenaCountdownDB or {}
        for key, value in pairs(ns.DEFAULTS) do
            if RetailArenaCountdownDB[key] == nil then
                RetailArenaCountdownDB[key] = value
            end
        end
        ns.db = RetailArenaCountdownDB
        -- Keep only this language; the others are freed.
        local all = ns.ARENA_MESSAGES
        ns.messages = all[GetLocale()] or all["default"]
        ns.ARENA_MESSAGES = nil
    elseif event == "PLAYER_LOGIN" then
        self:UnregisterEvent(event)
        ns.SilenceGladdy()
    else
        ns.UpdateArenaState()
    end
end)
events:RegisterEvent("ADDON_LOADED")
events:RegisterEvent("PLAYER_LOGIN")
events:RegisterEvent("PLAYER_ENTERING_WORLD")
events:RegisterEvent("ZONE_CHANGED_NEW_AREA")

--[[
RetailArenaCountdown, for the 3.3.5a client (Wrath of the Lich King).

The arena countdown as in the modern game: big numbers in the middle of the
screen from 60 seconds down, a sound at 10 and on every second from 9 to 1,
and your faction's crest with a closing sound when the gates open. It works
on its own: Gladdy is not needed. If Gladdy is loaded, its own countdown is
switched off so the two never show at once; Gladdy's saved settings are not
changed.

Based on the arena countdown module of Gladdy (XiconQoo, DnB_Junkee, Knall,
Tsoukie), GPL-2.0. The number and crest images come from Gladdy; the sounds
are Blizzard's.

/racd          status and commands
/racd test     a 15-second countdown, to see it outside the arena
/racd size N   size in pixels, 64 to 512 (256 by default)
/racd on, /racd off
]]

RetailArenaCountdown = RetailArenaCountdown or {}
local RAC = RetailArenaCountdown

local ADDON = "RetailArenaCountdown"
local MEDIA = "Interface\\AddOns\\" .. ADDON .. "\\"
local IMAGES = MEDIA .. "Images\\"
local SOUND_TICK = MEDIA .. "Sounds\\UI_BattlegroundCountdown_Timer.ogg"
local SOUND_END = MEDIA .. "Sounds\\UI_BattlegroundCountdown_End.ogg"
local TEST_SECONDS = 15
local floor = math.floor

RAC.DEFAULTS = { enabled = true, size = 256, strata = "HIGH", level = 50 }

local events = CreateFrame("Frame")
RAC.events = events

-- Display ------------------------------------------------------------------

--- The frame in the middle of the screen: two textures for two-digit numbers
--- and one for a single digit or the crest.
function RAC.CreateDisplay()
    local frame = CreateFrame("Frame", "RetailArenaCountdownFrame", UIParent)
    frame:EnableMouse(false)
    frame:Hide()
    RAC.frame = frame
    RAC.tens = frame:CreateTexture(nil, "OVERLAY")
    RAC.ones = frame:CreateTexture(nil, "OVERLAY")
    RAC.single = frame:CreateTexture(nil, "OVERLAY")
    RAC.ApplyLayout()
end

--- Size, layer and position, from the saved settings.
function RAC.ApplyLayout()
    local size = RAC.db.size
    local offset = size / 8 + size / 16
    local frame = RAC.frame
    frame:SetFrameStrata(RAC.db.strata)
    frame:SetFrameLevel(RAC.db.level)
    frame:SetWidth(size)
    frame:SetHeight(size)
    frame:ClearAllPoints()
    frame:SetPoint("CENTER", UIParent, "CENTER", 0, 128)
    for _, texture in ipairs({ RAC.tens, RAC.ones, RAC.single }) do
        texture:SetWidth(size)
        texture:SetHeight(size)
        texture:ClearAllPoints()
    end
    RAC.tens:SetPoint("CENTER", frame, "CENTER", -offset, 0)
    RAC.ones:SetPoint("CENTER", frame, "CENTER", offset, 0)
    RAC.single:SetPoint("CENTER", frame, "CENTER", 0, 0)
end

function RAC.HideAll()
    RAC.frame:Hide()
    RAC.tens:Hide()
    RAC.ones:Hide()
    RAC.single:Hide()
end

--- The crest shown at 0: the player's faction, if it has one.
local function crest()
    local faction = UnitFactionGroup("player")
    if faction == "Alliance" or faction == "Horde" then
        return faction
    end
    return nil
end

-- Clock --------------------------------------------------------------------

-- A tick every second while the countdown runs. 3.3.5a has no C_Timer, so it
-- is an OnUpdate script that adds up the time between frames.
local clock = CreateFrame("Frame")
clock:Hide()
local sinceLastTick = 0
clock:SetScript("OnUpdate", function(_, elapsed)
    sinceLastTick = sinceLastTick + elapsed
    if sinceLastTick >= 1 then
        sinceLastTick = sinceLastTick - 1
        RAC.Tick()
    end
end)
RAC.clock = clock

function RAC.StartClock()
    sinceLastTick = 0
    clock:Show()
end

--- One second of the countdown: draws the number and plays its sound.
function RAC.Tick()
    local count = RAC.countdown
    if not RAC.db.enabled then
        RAC.HideAll()
        return
    end

    if count and count >= 10 and count <= 60 then
        -- Two digits. The tens are rounded down: 45 / 10 is 4.5 in Lua, and
        -- an image called "4.5" does not exist.
        RAC.single:Hide()
        RAC.tens:SetTexture(IMAGES .. floor(count / 10))
        RAC.ones:SetTexture(IMAGES .. count % 10)
        RAC.tens:Show()
        RAC.ones:Show()
        RAC.frame:SetScale(0.7)
        RAC.frame:Show()
        if count == 10 then
            PlaySoundFile(SOUND_TICK)
        end
    elseif count and count >= 0 and count < 10 then
        -- One digit, or the crest when the gates open.
        RAC.tens:Hide()
        RAC.ones:Hide()
        local image = count == 0 and crest() or (count > 0 and count) or nil
        if image then
            RAC.single:SetTexture(IMAGES .. image)
            RAC.single:Show()
        else
            RAC.single:Hide()
        end
        RAC.frame:SetScale(1.0)
        RAC.frame:Show()
        PlaySoundFile(count == 0 and SOUND_END or SOUND_TICK)
    else
        -- Before the first message, or after the crest: nothing to show. Once
        -- the countdown is over, everything goes back to how it was.
        RAC.HideAll()
        if count then
            RAC.Reset()
        end
        return
    end

    RAC.countdown = count - 1
end

-- Arena --------------------------------------------------------------------

--- A system message during the arena preparation: if it is one of the
--- countdown messages, the countdown jumps to its number of seconds.
function RAC.OnArenaMessage(message)
    if not message then
        return
    end
    for seconds, text in pairs(RAC.messages) do
        if message:find(text, 1, true) then
            -- "The battle has begun" arriving while the crest is up changes nothing.
            if RAC.countdown == 0 then
                return
            end
            RAC.countdown = seconds
            return
        end
    end
end

-- The boss emote frame repeats the arena messages in big letters. It is
-- silenced while the countdown runs, and only given back if it was this
-- addon that silenced it.
local function silenceBossEmotes()
    if not RaidBossEmoteFrame then
        return
    end
    -- If this client cannot tell, the frame is listening: that is the default.
    local listening = not RaidBossEmoteFrame.IsEventRegistered
        or RaidBossEmoteFrame:IsEventRegistered("CHAT_MSG_RAID_BOSS_EMOTE")
    if listening then
        RaidBossEmoteFrame:UnregisterEvent("CHAT_MSG_RAID_BOSS_EMOTE")
        RAC.silencedEmotes = true
    end
end

local function restoreBossEmotes()
    if RAC.silencedEmotes then
        RaidBossEmoteFrame:RegisterEvent("CHAT_MSG_RAID_BOSS_EMOTE")
        RAC.silencedEmotes = false
    end
end

function RAC.JoinedArena()
    RAC.inArena = true
    if not RAC.db.enabled or RAC.countdown then
        return
    end
    RAC.StartClock()
    events:RegisterEvent("CHAT_MSG_BG_SYSTEM_NEUTRAL")
    events:RegisterEvent("ARENA_OPPONENT_UPDATE")
    silenceBossEmotes()
end

function RAC.LeftArena()
    RAC.inArena = false
    RAC.Reset()
end

--- Stops the countdown and puts everything back.
function RAC.Reset()
    clock:Hide()
    RAC.countdown = nil
    events:UnregisterEvent("CHAT_MSG_BG_SYSTEM_NEUTRAL")
    events:UnregisterEvent("ARENA_OPPONENT_UPDATE")
    restoreBossEmotes()
    RAC.HideAll()
end

--- Called when the zone or the battlefield status changes.
function RAC.UpdateArenaState()
    local _, kind = IsInInstance()
    if kind == "arena" then
        if not RAC.inArena then
            RAC.JoinedArena()
        end
    elseif RAC.inArena then
        RAC.LeftArena()
    end
end

-- Gladdy -------------------------------------------------------------------

--- If Gladdy is loaded, its countdown never starts: the two methods that
--- start it are replaced, in memory only, by ones that do nothing. Gladdy
--- looks its methods up by name each time, so this is enough, and its saved
--- settings stay as the player left them. Returns true if it did it.
function RAC.SilenceGladdy()
    local Gladdy = LibStub and LibStub("Gladdy", true)
    local module = Gladdy and Gladdy.modules and Gladdy.modules["Arena Countdown"]
    if not module or module.silencedByRetailArenaCountdown then
        return false
    end
    module.JOINED_ARENA = function() end
    module.TestOnce = function() end
    module.silencedByRetailArenaCountdown = true
    return true
end

-- Commands -----------------------------------------------------------------

local function say(text)
    print("|cffffd100RetailArenaCountdown|r: " .. text)
end

function RAC.Command(input)
    local command, value = strtrim(input or ""):lower():match("^(%S*)%s*(.-)$")
    if command == "test" then
        RAC.countdown = TEST_SECONDS
        RAC.StartClock()
        say("test countdown started.")
    elseif command == "size" then
        local size = tonumber(value)
        if size and size >= 64 and size <= 512 then
            RAC.db.size = floor(size)
            RAC.ApplyLayout()
            say("size set to " .. RAC.db.size .. ".")
        else
            say("the size goes from 64 to 512, for example /racd size 256.")
        end
    elseif command == "on" or command == "off" then
        RAC.db.enabled = command == "on"
        if not RAC.db.enabled then
            RAC.Reset()
        end
        say(RAC.db.enabled and "on." or "off.")
    else
        say((RAC.db.enabled and "on" or "off") .. ", size " .. RAC.db.size .. ".")
        say("/racd test, /racd size 64-512, /racd on, /racd off")
    end
end

SLASH_RETAILARENACOUNTDOWN1 = "/racd"
SLASH_RETAILARENACOUNTDOWN2 = "/retailarenacountdown"
SlashCmdList.RETAILARENACOUNTDOWN = function(input)
    RAC.Command(input)
end

-- Events -------------------------------------------------------------------

events:RegisterEvent("ADDON_LOADED")
events:RegisterEvent("PLAYER_LOGIN")
events:RegisterEvent("PLAYER_ENTERING_WORLD")
events:RegisterEvent("ZONE_CHANGED_NEW_AREA")
events:RegisterEvent("UPDATE_BATTLEFIELD_STATUS")
events:SetScript("OnEvent", function(_, event, arg1, arg2)
    if event == "ADDON_LOADED" then
        if arg1 ~= ADDON then
            return
        end
        RetailArenaCountdownDB = RetailArenaCountdownDB or {}
        for key, value in pairs(RAC.DEFAULTS) do
            if RetailArenaCountdownDB[key] == nil then
                RetailArenaCountdownDB[key] = value
            end
        end
        RAC.db = RetailArenaCountdownDB
        RAC.messages = RAC.MessagesFor(GetLocale())
        RAC.CreateDisplay()
    elseif event == "PLAYER_LOGIN" then
        RAC.SilenceGladdy()
    elseif event == "CHAT_MSG_BG_SYSTEM_NEUTRAL" then
        RAC.OnArenaMessage(arg1)
    elseif event == "ARENA_OPPONENT_UPDATE" then
        -- An enemy seen while time is left means the match is already on.
        if arg2 == "seen" and RAC.countdown and RAC.countdown > 0 then
            RAC.Reset()
        end
    else
        RAC.UpdateArenaState()
    end
end)

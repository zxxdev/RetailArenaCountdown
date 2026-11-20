-- RetailArenaCountdown with the game played by tables: frames and textures
-- remember what they were told, sounds are recorded, and each test drives the
-- arena by sending events and ticking the clock. Run with `busted`.

local IMAGES = "Interface\\AddOns\\RetailArenaCountdown\\Images\\"
local TICK = "Interface\\AddOns\\RetailArenaCountdown\\Sounds\\UI_BattlegroundCountdown_Timer.ogg"
local END = "Interface\\AddOns\\RetailArenaCountdown\\Sounds\\UI_BattlegroundCountdown_End.ogg"

local function newRegion()
    local region = { shown = false, events = {}, scripts = {} }
    function region:Show() self.shown = true end
    function region:Hide() self.shown = false end
    function region:IsShown() return self.shown end
    function region:SetTexture(path) self.texture = path end
    function region:SetScale(scale) self.scale = scale end
    function region:RegisterEvent(event) self.events[event] = true end
    function region:UnregisterEvent(event) self.events[event] = nil end
    function region:IsEventRegistered(event) return self.events[event] == true end
    function region:SetScript(name, handler) self.scripts[name] = handler end
    function region:CreateTexture() return newRegion() end
    for _, name in ipairs({
        "EnableMouse", "SetFrameStrata", "SetFrameLevel", "SetWidth", "SetHeight",
        "ClearAllPoints", "SetPoint",
    }) do
        region[name] = function() end
    end
    return region
end

--- A fresh fake game, the addon loaded and logged in.
local function setupGame(options)
    options = options or {}
    local game = { sounds = {}, printed = {}, instance = "none" }

    _G.UIParent = newRegion()
    _G.CreateFrame = function() return newRegion() end
    _G.PlaySoundFile = function(path) table.insert(game.sounds, path) end
    _G.UnitFactionGroup = function() return options.faction or "Horde" end
    _G.IsInInstance = function() return game.instance ~= "none", game.instance end
    _G.GetLocale = function() return options.locale or "enUS" end
    _G.strtrim = function(text) return (text:gsub("^%s+", ""):gsub("%s+$", "")) end
    _G.print = function(text) table.insert(game.printed, text) end
    _G.SlashCmdList = {}
    _G.RaidBossEmoteFrame = newRegion()
    _G.RaidBossEmoteFrame:RegisterEvent("CHAT_MSG_RAID_BOSS_EMOTE")
    _G.LibStub = options.libStub
    _G.RetailArenaCountdown = nil
    _G.RetailArenaCountdownDB = options.saved

    dofile("Locales.lua")
    dofile("RetailArenaCountdown.lua")
    game.addon = _G.RetailArenaCountdown
    local onEvent = game.addon.events.scripts.OnEvent
    game.fire = function(event, ...) onEvent(nil, event, ...) end
    game.fire("ADDON_LOADED", "RetailArenaCountdown")
    game.fire("PLAYER_LOGIN")

    game.enterArena = function()
        game.instance = "arena"
        game.fire("PLAYER_ENTERING_WORLD")
    end
    game.leaveArena = function()
        game.instance = "none"
        game.fire("PLAYER_ENTERING_WORLD")
    end
    -- One second passes.
    game.tick = function() game.addon.clock.scripts.OnUpdate(nil, 1) end
    game.say = function(message) game.fire("CHAT_MSG_BG_SYSTEM_NEUTRAL", message) end
    return game
end

local function digits(game)
    local addon = game.addon
    return {
        tens = addon.tens.shown and addon.tens.texture or nil,
        ones = addon.ones.shown and addon.ones.texture or nil,
        single = addon.single.shown and addon.single.texture or nil,
    }
end

describe("the countdown", function()
    it("starts from the game's message, in the client's language", function()
        local game = setupGame({ locale = "esES" })
        game.enterArena()
        game.say("¡Un minuto hasta que dé comienzo la batalla en arena!")
        assert.equal(60, game.addon.countdown)
    end)

    it("uses the English messages for a language it does not know", function()
        local game = setupGame({ locale = "itIT" })
        game.enterArena()
        game.say("Thirty seconds until the Arena battle begins!")
        assert.equal(30, game.addon.countdown)
    end)

    it("shows both digits of 45, not an image called 4.5", function()
        local game = setupGame()
        game.enterArena()
        game.addon.countdown = 45
        game.tick()
        assert.same({ tens = IMAGES .. "4", ones = IMAGES .. "5" }, digits(game))
        assert.equal(0.7, game.addon.frame.scale)
    end)

    it("shows one digit below 10, at full size", function()
        local game = setupGame()
        game.enterArena()
        game.addon.countdown = 7
        game.tick()
        assert.same({ single = IMAGES .. "7" }, digits(game))
        assert.equal(1.0, game.addon.frame.scale)
    end)

    it("plays a sound at 10 and on every second from 9 to 1, and the closing one at 0", function()
        local game = setupGame()
        game.enterArena()
        game.addon.countdown = 12
        for _ = 12, 0, -1 do
            game.tick()
        end
        local expected = { TICK } -- 10
        for _ = 9, 1, -1 do
            table.insert(expected, TICK)
        end
        table.insert(expected, END) -- 0
        assert.same(expected, game.sounds)
    end)

    it("shows the player's faction crest when the gates open", function()
        local game = setupGame({ faction = "Alliance" })
        game.enterArena()
        game.addon.countdown = 0
        game.tick()
        assert.same({ single = IMAGES .. "Alliance" }, digits(game))
    end)

    it("ignores a second 'battle has begun' while the crest is up", function()
        local game = setupGame()
        game.enterArena()
        game.say("The Arena battle has begun!")
        assert.equal(0, game.addon.countdown)
        game.say("One minute until the Arena battle begins!")
        assert.equal(0, game.addon.countdown)
    end)

    it("puts everything back once the crest has been shown", function()
        local game = setupGame()
        game.enterArena()
        game.addon.countdown = 0
        game.tick() -- crest
        game.tick() -- over
        assert.is_false(game.addon.frame.shown)
        assert.is_false(game.addon.clock.shown)
        assert.is_nil(game.addon.countdown)
        assert.is_nil(game.addon.events.events.CHAT_MSG_BG_SYSTEM_NEUTRAL)
        assert.is_true(_G.RaidBossEmoteFrame:IsEventRegistered("CHAT_MSG_RAID_BOSS_EMOTE"))
    end)
end)

describe("the arena", function()
    it("listens to the arena messages and silences boss emotes only inside an arena", function()
        local game = setupGame()
        assert.is_nil(game.addon.events.events.CHAT_MSG_BG_SYSTEM_NEUTRAL)

        game.enterArena()
        assert.is_true(game.addon.events.events.CHAT_MSG_BG_SYSTEM_NEUTRAL)
        assert.is_false(_G.RaidBossEmoteFrame:IsEventRegistered("CHAT_MSG_RAID_BOSS_EMOTE"))

        game.leaveArena()
        assert.is_nil(game.addon.events.events.CHAT_MSG_BG_SYSTEM_NEUTRAL)
        assert.is_true(_G.RaidBossEmoteFrame:IsEventRegistered("CHAT_MSG_RAID_BOSS_EMOTE"))
    end)

    it("does not give boss emotes back if another addon had silenced them", function()
        local game = setupGame()
        _G.RaidBossEmoteFrame:UnregisterEvent("CHAT_MSG_RAID_BOSS_EMOTE")
        game.enterArena()
        game.leaveArena()
        assert.is_false(_G.RaidBossEmoteFrame:IsEventRegistered("CHAT_MSG_RAID_BOSS_EMOTE"))
    end)

    it("stops when an enemy is seen while time is left", function()
        local game = setupGame()
        game.enterArena()
        game.addon.countdown = 20
        game.fire("ARENA_OPPONENT_UPDATE", "arena1", "seen")
        assert.is_nil(game.addon.countdown)
        assert.is_false(game.addon.frame.shown)
    end)

    it("keeps the crest when an enemy is seen at 0", function()
        local game = setupGame()
        game.enterArena()
        game.addon.countdown = 0
        game.fire("ARENA_OPPONENT_UPDATE", "arena1", "seen")
        assert.equal(0, game.addon.countdown)
    end)
end)

describe("Gladdy", function()
    it("its countdown never starts, and its saved settings are untouched", function()
        local started = false
        local module = {
            JOINED_ARENA = function() started = true end,
            TestOnce = function() started = true end,
        }
        local gladdy = { modules = { ["Arena Countdown"] = module }, db = { countdown = true } }
        local game = setupGame({
            libStub = function(name, silent)
                assert.equal("Gladdy", name)
                assert.is_true(silent)
                return gladdy
            end,
        })
        assert.is_true(module.silencedByRetailArenaCountdown)
        module.JOINED_ARENA(module)
        module.TestOnce(module)
        assert.is_false(started)
        assert.is_true(gladdy.db.countdown)
        assert.is_false(game.addon.SilenceGladdy()) -- only once
    end)

    it("is not needed", function()
        local game = setupGame({ libStub = nil })
        assert.is_false(game.addon.SilenceGladdy())
    end)
end)

describe("settings and commands", function()
    it("fills in the defaults and keeps what the player saved", function()
        local game = setupGame({ saved = { size = 128 } })
        assert.equal(128, game.addon.db.size)
        assert.is_true(game.addon.db.enabled)
    end)

    it("/racd test runs a 15-second countdown outside the arena", function()
        local game = setupGame()
        _G.SlashCmdList.RETAILARENACOUNTDOWN("test")
        game.tick()
        assert.same({ tens = IMAGES .. "1", ones = IMAGES .. "5" }, digits(game))
    end)

    it("/racd size accepts 64 to 512 and refuses anything else", function()
        local game = setupGame()
        _G.SlashCmdList.RETAILARENACOUNTDOWN("size 600")
        assert.equal(256, game.addon.db.size)
        _G.SlashCmdList.RETAILARENACOUNTDOWN("size 128")
        assert.equal(128, game.addon.db.size)
    end)

    it("/racd off hides it and stops it showing", function()
        local game = setupGame()
        game.enterArena()
        game.addon.countdown = 30
        _G.SlashCmdList.RETAILARENACOUNTDOWN("off")
        assert.is_false(game.addon.db.enabled)
        assert.is_false(game.addon.frame.shown)
        game.addon.countdown = 30
        game.tick()
        assert.is_false(game.addon.frame.shown)
    end)
end)

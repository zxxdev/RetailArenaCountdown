-- RetailArenaCountdown with the game played by tables: frames and textures
-- remember what they were told, sounds are recorded, and each test drives the
-- arena by sending events and ticking the clock. The addon is loaded the way
-- the game loads it, with its private namespace. Run with `busted`.

local MEDIA = "Interface\\AddOns\\RetailArenaCountdown\\"
local IMAGES = MEDIA .. "Images\\"
local TICK = MEDIA .. "Sounds\\UI_BattlegroundCountdown_Timer.ogg"
local END = MEDIA .. "Sounds\\UI_BattlegroundCountdown_End.ogg"

local function newRegion(game)
    local region = { shown = false, events = {}, scripts = {} }
    function region.Show(r) r.shown = true end
    function region.Hide(r) r.shown = false end
    function region.IsShown(r) return r.shown end
    function region.SetTexture(r, path) r.texture = path end
    function region.SetScale(r, scale) r.scale = scale end
    function region.RegisterEvent(r, event) r.events[event] = true end
    function region.UnregisterEvent(r, event) r.events[event] = nil end
    function region.IsEventRegistered(r, event) return r.events[event] == true end
    function region.SetScript(r, name, handler) r.scripts[name] = handler end
    function region.CreateTexture()
        game.textures = game.textures + 1
        return newRegion(game)
    end
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
    local game = { sounds = {}, printed = {}, instance = "none", frames = 0, textures = 0 }

    _G.UIParent = newRegion(game)
    _G.CreateFrame = function()
        game.frames = game.frames + 1
        return newRegion(game)
    end
    _G.PlaySoundFile = function(path) table.insert(game.sounds, path) end
    _G.UnitFactionGroup = function() return options.faction or "Horde" end
    _G.IsInInstance = function() return game.instance ~= "none", game.instance end
    _G.GetLocale = function() return options.locale or "enUS" end
    _G.print = function(text) table.insert(game.printed, text) end
    _G.SlashCmdList = {}
    _G.RaidBossEmoteFrame = newRegion(game)
    _G.RaidBossEmoteFrame:RegisterEvent("CHAT_MSG_RAID_BOSS_EMOTE")
    _G.LibStub = options.libStub
    _G.RetailArenaCountdownDB = options.saved

    local ns = {}
    assert(loadfile("Locales.lua"))("RetailArenaCountdown", ns)
    assert(loadfile("RetailArenaCountdown.lua"))("RetailArenaCountdown", ns)
    game.addon = ns
    game.fire = function(event, ...) ns.events.scripts.OnEvent(ns.events, event, ...) end
    game.fire("ADDON_LOADED", "SomeOtherAddon")
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
    game.tick = function() ns.clock.scripts.OnUpdate(ns.clock, 1) end
    game.say = function(message) game.fire("CHAT_MSG_BG_SYSTEM_NEUTRAL", message) end
    game.visible = function() return ns.frame ~= nil and ns.frame.shown end
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

--- Enter an arena and start counting from `seconds`, as the game would.
local function countFrom(game, seconds)
    game.enterArena()
    game.addon.countdown = seconds
    game.addon.clock:Show()
end

describe("the countdown", function()
    it("starts from the game's message, in the client's language", function()
        local game = setupGame({ locale = "esES" })
        game.enterArena()
        game.say("¡Un minuto hasta que dé comienzo la batalla en arena!")
        assert.same({ tens = IMAGES .. "6", ones = IMAGES .. "0" }, digits(game))
        assert.is_true(game.addon.clock.shown)
    end)

    it("shows the number the moment the message arrives, not a second later", function()
        local game = setupGame()
        game.enterArena()
        game.say("Fifteen seconds until the Arena battle begins!")
        assert.same({ tens = IMAGES .. "1", ones = IMAGES .. "5" }, digits(game))
        game.tick()
        assert.same({ tens = IMAGES .. "1", ones = IMAGES .. "4" }, digits(game))
    end)

    it("uses the English messages for a language it does not know", function()
        local game = setupGame({ locale = "itIT" })
        game.enterArena()
        game.say("Thirty seconds until the Arena battle begins!")
        assert.same({ tens = IMAGES .. "3", ones = IMAGES .. "0" }, digits(game))
    end)

    it("shows both digits of 45, not an image called 4.5", function()
        local game = setupGame()
        countFrom(game, 45)
        game.tick()
        assert.same({ tens = IMAGES .. "4", ones = IMAGES .. "5" }, digits(game))
        assert.equal(0.7, game.addon.frame.scale)
    end)

    it("shows one digit below 10, at full size", function()
        local game = setupGame()
        countFrom(game, 7)
        game.tick()
        assert.same({ single = IMAGES .. "7" }, digits(game))
        assert.equal(1.0, game.addon.frame.scale)
    end)

    it("plays a sound at 10 and on every second from 9 to 1, and the closing one at 0", function()
        local game = setupGame()
        countFrom(game, 12)
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
        countFrom(game, 0)
        game.tick()
        assert.same({ single = IMAGES .. "Alliance" }, digits(game))
    end)

    it("ignores a second 'battle has begun' while the crest is up", function()
        local game = setupGame()
        game.enterArena()
        game.say("The Arena battle has begun!")
        assert.same({ single = IMAGES .. "Horde" }, digits(game))
        game.say("One minute until the Arena battle begins!")
        assert.same({ single = IMAGES .. "Horde" }, digits(game))
        assert.same({ END }, game.sounds)
    end)

    it("puts everything back once the crest has been shown", function()
        local game = setupGame()
        countFrom(game, 0)
        game.tick() -- crest
        game.tick() -- over
        assert.is_false(game.visible())
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

    it("gives boss emotes back as soon as the gates open, not when leaving", function()
        local game = setupGame()
        countFrom(game, 0)
        assert.is_false(_G.RaidBossEmoteFrame:IsEventRegistered("CHAT_MSG_RAID_BOSS_EMOTE"))
        game.tick() -- crest
        game.tick() -- over, still in the arena
        assert.is_true(_G.RaidBossEmoteFrame:IsEventRegistered("CHAT_MSG_RAID_BOSS_EMOTE"))
    end)

    it("leaves boss emotes alone if another addon turned them back on meanwhile", function()
        local game = setupGame()
        game.enterArena()
        local frame = _G.RaidBossEmoteFrame
        frame:RegisterEvent("CHAT_MSG_RAID_BOSS_EMOTE") -- someone else
        local register = frame.RegisterEvent
        local calls = 0
        frame.RegisterEvent = function(...)
            calls = calls + 1
            return register(...)
        end
        game.leaveArena()
        assert.equal(0, calls)
        assert.is_true(frame:IsEventRegistered("CHAT_MSG_RAID_BOSS_EMOTE"))
    end)

    it("stops when an enemy is seen while time is left", function()
        local game = setupGame()
        countFrom(game, 20)
        game.tick()
        game.fire("ARENA_OPPONENT_UPDATE", "arena1", "seen")
        assert.is_nil(game.addon.countdown)
        assert.is_false(game.visible())
    end)

    it("keeps the crest when an enemy is seen at 0", function()
        local game = setupGame()
        countFrom(game, 0)
        game.fire("ARENA_OPPONENT_UPDATE", "arena1", "seen")
        assert.equal(0, game.addon.countdown)
    end)
end)

describe("light on the game", function()
    it("creates no display until the first countdown", function()
        local game = setupGame()
        game.enterArena()
        assert.is_nil(game.addon.frame)
        assert.equal(0, game.textures)
        game.say("Fifteen seconds until the Arena battle begins!")
        assert.equal(3, game.textures)
    end)

    it("keeps only the player's language of the arena messages", function()
        local game = setupGame({ locale = "deDE" })
        assert.is_nil(game.addon.ARENA_MESSAGES)
        assert.equal("Der Arenakampf hat begonnen!", game.addon.messages[0])
    end)

    it("runs its clock only while a countdown is on screen", function()
        local game = setupGame()
        assert.is_false(game.addon.clock.shown)
        game.enterArena()
        assert.is_false(game.addon.clock.shown) -- in the arena, but no message yet
        game.say("Fifteen seconds until the Arena battle begins!")
        assert.is_true(game.addon.clock.shown)
    end)

    it("stops listening to load events once it has loaded, and never to queue updates", function()
        local game = setupGame()
        assert.is_nil(game.addon.events.events.ADDON_LOADED)
        assert.is_nil(game.addon.events.events.PLAYER_LOGIN)
        assert.is_nil(game.addon.events.events.UPDATE_BATTLEFIELD_STATUS)
    end)

    it("leaves nothing global except its saved settings and slash command", function()
        setupGame()
        assert.is_nil(rawget(_G, "RetailArenaCountdown"))
        assert.is_table(rawget(_G, "RetailArenaCountdownDB"))
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
        assert.is_true(game.addon.db.hideEmotes)
    end)

    it("/racd test runs a 15-second countdown outside the arena", function()
        local game = setupGame()
        _G.SlashCmdList.RETAILARENACOUNTDOWN("test")
        assert.same({ tens = IMAGES .. "1", ones = IMAGES .. "5" }, digits(game))
    end)

    it("/racd test while waiting in the arena still lets the real countdown come", function()
        local game = setupGame()
        game.enterArena()
        _G.SlashCmdList.RETAILARENACOUNTDOWN("test")
        for _ = 1, 16 do
            game.tick() -- 14 down to the crest, then the test is over
        end
        assert.is_false(game.visible())
        assert.is_true(game.addon.events.events.CHAT_MSG_BG_SYSTEM_NEUTRAL)
        game.say("Thirty seconds until the Arena battle begins!")
        assert.same({ tens = IMAGES .. "3", ones = IMAGES .. "0" }, digits(game))
    end)

    it("/racd test does not cut a real countdown short", function()
        local game = setupGame()
        game.enterArena()
        game.say("Thirty seconds until the Arena battle begins!")
        _G.SlashCmdList.RETAILARENACOUNTDOWN("test")
        assert.same({ tens = IMAGES .. "3", ones = IMAGES .. "0" }, digits(game))
    end)

    it("/racd on inside the arena starts listening again", function()
        local game = setupGame()
        game.enterArena()
        _G.SlashCmdList.RETAILARENACOUNTDOWN("off")
        assert.is_nil(game.addon.events.events.CHAT_MSG_BG_SYSTEM_NEUTRAL)
        _G.SlashCmdList.RETAILARENACOUNTDOWN("on")
        assert.is_true(game.addon.events.events.CHAT_MSG_BG_SYSTEM_NEUTRAL)
        game.say("Fifteen seconds until the Arena battle begins!")
        assert.is_true(game.visible())
    end)

    it("/racd size accepts 64 to 512 and refuses anything else", function()
        local game = setupGame()
        _G.SlashCmdList.RETAILARENACOUNTDOWN("size 600")
        assert.equal(256, game.addon.db.size)
        _G.SlashCmdList.RETAILARENACOUNTDOWN("  SIZE 128 ")
        assert.equal(128, game.addon.db.size)
    end)

    it("/racd emotes show never touches boss emotes, and gives them back at once", function()
        local game = setupGame()
        game.enterArena()
        assert.is_false(_G.RaidBossEmoteFrame:IsEventRegistered("CHAT_MSG_RAID_BOSS_EMOTE"))
        _G.SlashCmdList.RETAILARENACOUNTDOWN("emotes show")
        assert.is_false(game.addon.db.hideEmotes)
        assert.is_true(_G.RaidBossEmoteFrame:IsEventRegistered("CHAT_MSG_RAID_BOSS_EMOTE"))
        game.leaveArena()
        game.enterArena()
        assert.is_true(_G.RaidBossEmoteFrame:IsEventRegistered("CHAT_MSG_RAID_BOSS_EMOTE"))
        _G.SlashCmdList.RETAILARENACOUNTDOWN("emotes hide")
        assert.is_true(game.addon.db.hideEmotes)
    end)

    it("/racd off hides it and stops it showing", function()
        local game = setupGame()
        countFrom(game, 30)
        game.tick()
        _G.SlashCmdList.RETAILARENACOUNTDOWN("off")
        assert.is_false(game.addon.db.enabled)
        assert.is_false(game.visible())
        game.addon.countdown = 30
        game.tick()
        assert.is_false(game.visible())
    end)
end)

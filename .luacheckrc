-- Lua 5.1, the version of the 3.3.5a client.
std = "lua51"
max_line_length = 120
exclude_files = { ".luarocks", "lua_modules" }

-- What the addon defines for the game.
globals = {

    "RetailArenaCountdownDB",
    "SLASH_RETAILARENACOUNTDOWN1",
    "SLASH_RETAILARENACOUNTDOWN2",
    "SlashCmdList",
}

-- Game API the addon reads.
read_globals = {
    "CreateFrame",
    "GetLocale",
    "IsInInstance",
    "LibStub",
    "PlaySoundFile",
    "RaidBossEmoteFrame",
    "UIParent",
    "UnitFactionGroup",
}

files["spec/**/*.lua"] = {
    std = "+busted",
    -- The tests play the game API, so they define it.
    globals = { "_G" },
    allow_defined_top = true,
    max_line_length = 130,
}

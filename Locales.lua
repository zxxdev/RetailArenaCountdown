-- The messages the game prints before an arena match, in each client
-- language, and how many seconds are left when each one appears. Taken from
-- Gladdy (Constants_shared.lua), GPL-2.0.

RetailArenaCountdown = RetailArenaCountdown or {}

RetailArenaCountdown.ARENA_MESSAGES = {
    ["default"] = {
        [60] = "One minute until the Arena battle begins!",
        [30] = "Thirty seconds until the Arena battle begins!",
        [15] = "Fifteen seconds until the Arena battle begins!",
        [0] = "The Arena battle has begun!",
    },
    ["esES"] = {
        [60] = "¡Un minuto hasta que dé comienzo la batalla en arena!",
        [30] = "¡Treinta segundos hasta que comience la batalla en arena!",
        [15] = "¡Quince segundos hasta que comience la batalla en arena!",
        [0] = "¡La batalla en arena ha comenzado!",
    },
    ["ptBR"] = {
        [60] = "Um minuto até a batalha na Arena começar!",
        [30] = "Trinta segundos até a batalha na Arena começar!",
        [15] = "Quinze segundos até a batalha na Arena começar!",
        [0] = "A batalha na Arena começou!",
    },
    ["deDE"] = {
        [60] = "Noch eine Minute bis der Arenakampf beginnt!",
        [30] = "Noch dreißig Sekunden bis der Arenakampf beginnt!",
        [15] = "Noch fünfzehn Sekunden bis der Arenakampf beginnt!",
        [0] = "Der Arenakampf hat begonnen!",
    },
    ["frFR"] = {
        [60] = "Le combat d'arène commence dans une minute\194\160!",
        [30] = "Le combat d'arène commence dans trente secondes\194\160!",
        [15] = "Le combat d'arène commence dans quinze secondes\194\160!",
        [0] = "Le combat d'arène commence\194\160!",
    },
    ["ruRU"] = {
        [60] = "Одна минута до начала боя на арене!",
        [30] = "Тридцать секунд до начала боя на арене!",
        [15] = "До начала боя на арене осталось 15 секунд.",
        [0] = "Бой начался!",
    },
    ["koKR"] = {
        [60] = "투기장 전투 시작 1분 전입니다!",
        [30] = "투기장 전투 시작 30초 전입니다!",
        [15] = "투기장 전투 시작 15초 전입니다!",
        [0] = "투기장 전투가 시작되었습니다!",
    },
    ["zhCN"] = {
        [60] = "竞技场战斗将在一分钟后开始！",
        [30] = "竞技场战斗将在三十秒后开始！",
        [15] = "竞技场战斗将在十五秒后开始！",
        [0] = "竞技场的战斗开始了！",
    },
    ["zhTW"] = {
        [60] = "1分鐘後競技場戰鬥開始!",
        [30] = "30秒後競技場戰鬥開始!",
        [15] = "15秒後競技場戰鬥開始!",
        [0] = "競技場戰鬥開始了!",
    },
}

local messages = RetailArenaCountdown.ARENA_MESSAGES
messages["esMX"] = messages["esES"]
messages["ptPT"] = messages["ptBR"]

--- The messages for a client language, or the English ones when it has none.
function RetailArenaCountdown.MessagesFor(locale)
    return messages[locale] or messages["default"]
end
